<?php

$docRoot = getenv("DOCUMENT_ROOT");
require_once $docRoot . '/mobi-config/mobi_lib_constants.php';
require_once '../page_builder/url_decoder.php';

$decimal_id = expand_id($_REQUEST['short_id']);

header("Location: " . EVENTS_CALENDAR_UNIQUE_EVENT_URL . $decimal_id);

?>