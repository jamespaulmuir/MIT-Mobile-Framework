<?php


require_once "../config/mobi_web_constants.php";
require_once PAGE_HEADER;
require_once LIBDIR . "StellarData.php";
require_once "stellar_lib.php";

$which = $_REQUEST['which'];

if($which == "other") {
  $courses = StellarData::get_others();
  $title = "Other Courses";
} else {
  $all_courses = StellarData::get_courses();
  $drill = new DrillNumeralAlpha($which, "key");
  $courses = $drill->get_list($all_courses);
  $title = "Courses $which";
}

require "$page->branch/courses.html";

$page->output();
    
?>
