<?

$docRoot = getenv("DOCUMENT_ROOT");

class DataServerException extends Exception {
}

require_once $docRoot . "/mobi-config/mobi_web_constants.php";
require_once WEBROOT . "page_builder/counter.php";

$APIROOT = dirname(__FILE__);

?>
