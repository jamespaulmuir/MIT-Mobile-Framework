<?

//$docRoot = getenv("DOCUMENT_ROOT");
//require_once $docRoot . "/mobi-config/mobi_lib_constants.php";

// TODO: move to constants file
define('TMP_DIR', '/tmp/'); // cache files that we'll allow the OS to clean out
define('EVENTS_CALENDAR_API', 'http://events.mit.edu/MITEventsFull.wsdl');

MIT_Calendar::init();

// TODO: custom Exception types should be defined somewhere accessible
// to classes that throw them (i.e. in mobi-lib), instead we are
// depending on them to be defined downstream in mobi-web (mobi-sms
// doesn't even define them)
class SoapClientWrapper {
  /* 
    This Wrapper automatically invokes ther generic error handler
    When the Soap Server returns an exception
  */ 
  private $php_client;

  public function __construct($url) {
    $this->php_client = new SoapClient($url);
  }

  public function __call($method, $args) {
    try {
      return call_user_func_array(array($this->php_client, $method), $args);  
    } catch(SoapFault $error) {
      $msg = $error->getMessage();
      if (!$msg) $msg = "";
      throw new DataServerException("MIT Calendar SOAP server problem: $msg");
    }
  }

}

class MIT_Calendar {
  private static $php_client = NULL;

  private static $common_words = Array(
    "", "a", "the", "in", "of", "at", "i", // words we actually received in queries
    "and", "or", // some other obvious words
    );

  // this is the most requested query, so we make a cache both in
  // memory and on disk; all other days will be cached on disk
  private static $today_events;

  public static function init() {
    if(!self::$php_client) {
      self::$php_client = new SoapClientWrapper(EVENTS_CALENDAR_API);
    }
  }

  private static function write_cache($event_type, $data, $tmp=FALSE) {
    if ($tmp)
      $filename = TMP_DIR . $event_type;
    else
      $filename = CACHE_DIR . 'EVENTS_CALENDAR/' . $event_type;

    $fh = fopen($filename, 'w');
    fwrite($fh, serialize($data));
    fclose($fh);
  }

  private static function write_temp_cache($event_type, $data) {
    self::write_cache($event_type, $data, TRUE);
  }

  private static function read_cache($event_type, $tmp=FALSE) {
    // TODO: move timeout value to constants file
    $timeout = 86400;

    if ($tmp)
      $filename = TMP_DIR . $event_type;
    else
      $filename = CACHE_DIR . 'EVENTS_CALENDAR/' . $event_type;

    if (file_exists($filename) && filemtime($filename) < time() + $timeout) {
      return unserialize(file_get_contents($filename));
    }
    return FALSE;
  }

  private static function read_temp_cache($event_type) {
    return self::read_cache($event_type, TRUE);
  }

  public static function Categorys() {
    return self::$php_client->getCategoryList();
  }

  public static function Category($id) {
    return self::$php_client->getCategory($id);
  }  

  public static function subCategorys($category) {
    return self::$php_client->getCategoryList($category->catid);
  }

  public static function TodaysExhibitsHeaders($date) {
    return self::HeadersByCatID(5, $date, $date);
  }

  public static function ThisWeeksExhibitsHeaders($date) {
    $end = date('Y/m/d', strtotime($date) + 86400 * 7);
    $result = array();
    $events = self::HeadersByCatID(5, $date, $end);
    // for multi-day exhibits, the SOAP API returns a separate event
    // for each day with an incrementing event ID.
    $unique_titles = array(); // id => title
    foreach ($events as $event) {
      $id = $event->id;
      $unique_titles[$id] = $event->title;
      while (array_key_exists($id - 1, $unique_titles)
	     && $unique_titles[$id - 1] == $event->title) {
	$id -= 1;
      }

      if ($id == $event->id) {
	$result[$id] = $event;
      } else {
	$result[$id]->end = $event->end;
      }
    }

    return $result;
  }

  public static function CategoryEventsHeaders($category, $start, $end=NULL) {
    if(!$end) {
      $end = $start;
    }
    return self::HeadersByCatID($category->catid, $start, $end);
  }

  public static function HeadersByCatID($catID, $start, $end) {
    $criteria = array(
      new SearchCriterion('start', $start),
      new SearchCriterion('end', $end),
      new SearchCriterion('catid', $catID) 
    );
    return self::$php_client->findEventsHeaders(SearchCriterion::forSOAP($criteria));
  }

  public static function hourSearch($date, $hour, $offsetHours = 1) {
    $time1 = strtotime("$date $hour:00:00");
    $time2 = $time1 + 60 * 60 * $offsetHours - 1;
    $start = date('Y/m/d H:00:00', $time1);
    $end = date('Y/m/d H:00:00', $time2);

    $criteria = array(
      new SearchCriterion('start', $start),
      new SearchCriterion('end', $end),
    );
    return self::$php_client->findEventsHeaders(SearchCriterion::forSOAP($criteria));
  }

  private static function wordSearch($word, $start, $end, $category) {
    $cachename = 'calsearch_' . $word . '_' 
      . str_replace('/', '', $start) . '_' . str_replace('/', '', $end);

    if ($category) {
      $cachename .= '_' . $category->catid;
    }

    if ($results = self::read_temp_cache($cachename)) {
      return $results;
    }

    $criteria = array(
      new SearchCriterion('start', $start),
      new SearchCriterion('end', $end),
      new SearchCriterion('fulltext', $word)
    );

    if($category) {
      $criteria[] = new SearchCriterion('catid', $category->catid);
    }

    $results = self::$php_client->findEventsHeaders(SearchCriterion::forSOAP($criteria));

    self::write_temp_cache($cachename, $results);
    return $results;
  }

  public static function fullTextSearch($text, $start, $end, $category=NULL) {
    // the soap api interprets each string argument as a quoted string
    // search.  multiple arguments are interpreted as an OR query
    // instead of AND query.  so we employ some heuristics here to
    // narrow down search results

    // search in decreasing token size
    $tokens = split(' ', $text);
    usort($tokens, array(self, 'compare_strlen'));
    $longest_token = array_shift($tokens);

    // if all tokens are very short, use the full string
    if (strlen($longest_token) < 4) {
      $results = self::wordSearch($text, $start, $end, $category);
      return $results;
    }

    $results = self::wordSearch($longest_token, $start, $end, $category);

    foreach ($tokens as $token) {
      if (in_array($token, self::$common_words)) continue;
      $new_results = self::wordSearch($token, $start, $end, $category);
      $results = array_uintersect($results, $new_results, array(self, "compare_events"));

      // ignore the rest of the tokens if we're down to a few results
      if (count($results) < 5) {
	break;
      }
    }

    return $results;
  }

  public static function TodaysEventsHeaders($date=NULL) {
    $today_date = date('Y/m/d');
    if ($date === NULL)
      $date = $today_date;

    if (($events = self::$today_events) !== NULL
	&& ($today_date == $date)) {
      return $events;
    }

    $hard_cache = 'day_' . str_replace('/', '', $date);
    if ($events = self::read_cache($hard_cache)) {
      return $events;
    }

    // Get all today's events including exhibits
    $all_events = self::$php_client->getDayEventsHeaders($date);
    
    // Get only exhibits
    $exhibitions = self::TodaysExhibitsHeaders($date);
   
    $without_exhibitions = array(); //Initalize empty array
    
    //Remove the exhibitions form the list of today's events
    foreach($all_events as $event) {

      $found = false; //Initialize $found flag
      $id = $event->id;
      // Search through the list of exhibits to see if it matches the event id
      foreach($exhibitions as $exhibition) {
        if($exhibition->id == $id) {
          $found = true;
        }
      }

      if(!$found) {
        // Not an exhibition so add it to the list
        $without_exhibitions[] = $event;
      }
    }

    if (count($without_exhibitions)) {
      if ($today_date == $date) {
	self::$today_events = $without_exhibitions;
      }

      self::write_cache($hard_cache, $without_exhibitions);
    }

    return $without_exhibitions;
  }     

  public static function getEvent($id) {
    try {
      return self::$php_client->getEvent($id);
    } catch (Exception $e) {
      // see if this event is in our "today" cache, if so return that
      // instead.  log the error instead of showing "Internal Server
      // Error" page.  this will cover the majority of detail pages
      // requested.
      foreach (self::TodaysEventsHeaders() as $event) {
	// fields we use in detail screen: title, shortloc | location,
	// infophone, description, infourl, categories.
	// fields NOT included in headers:
	// infophone, description, infourl, categories
	if ($event->id == $id) {
	  $event->description = "Problem retrieving details from data server.  Please try again later.";
	  $event->categories = array();
	  error_log("Failed to get event details for event id $id: " . $e->getMessage());
	  return $event;
	}
      }
      throw $e;
    }
  }

  public static function standard_time($hour, $minute) {
    $end = ($hour < 12) ? 'am' : 'pm';
    $hour = $hour % 12;
    if($hour == 0) {
      $hour = 12;
    }
    if($minute < 10) {
      $minute = '0' . (int) $minute;
    }
    return "$hour:$minute$end";
  }

  public static function timeText($event) {
    $out = '';

    if($event->start->hour === '00' &&
       $event->start->minute === '00' && (
        ($event->end->hour === '00' && $event->end->minute === '00')  ||
        ($event->end->hour === '23' && $event->end->minute === '59')) )  {
          $out = 'All day';
    } else {
       if($event->start) {
         $out = self::standard_time($event->start->hour, $event->start->minute);
       }
       if($event->end && self::compare($event->start, $event->end) == -1) {
         $out .= '-';
         $out .= self::standard_time($event->end->hour, $event->end->minute);
       }
    }
    return $out;
  }

  public static function compare($day1, $day2) {
    //compare the two different times
    foreach(array("year", "month", "day", "hour", "minute") as $key) {
      if($day1->$key > $day2->$key) {
        return 1;
      }

      if($day2->$key > $day1->$key) {
        return -1;
      }
    }
    return 0;
  }

  public static function compare_events($event1, $event2) {
    $id1 = $event1->id;
    $id2 = $event2->id;

    if ($id1 == $id2) {
      return 0;
    }
    return ($id1 < $id2) ? -1 : 1;
  }

  /* sort an array of strings in DESCENDING order. */
  public static function compare_strlen($str1, $str2) {
    if (strlen($str1) == strlen($str2)) return 0;
    return (strlen($str1) < strlen($str2)) ? 1 : -1;
  }

}

class SearchCriterion {
  
  private $field;
  private $value;

  public function __construct($field) {
    $this->field = $field;
    $args = func_get_args();
    $this->value = array_slice($args, 1);    
  }

  public function addValue($value) {
    $this->value[] = $value;
  }

  public static function forSOAP(array $criteria) {
    $soap_array = array();
    foreach($criteria as $criterian) {
      $soap_array[] = array(
	"field" => $criterian->field,
	"value" => $criterian->value,
      );
    }
    return $soap_array;
  }

  public static function fromArray($field, $values) {
    $new_obj = new self($field);
    $new_obj->value = $values;
    return $new_obj;
  }
}

?>
