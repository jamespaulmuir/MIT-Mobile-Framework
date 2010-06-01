<?php


require_once "../config/mobi_web_constants.php";
require_once PAGE_HEADER;
require_once LIBDIR . "rss_services.php";

$ThreeDown = new ThreeDown();
$states = $ThreeDown->get_feed();

function detailURL($title) {
  return "detail.php?title=$title";
}

function is_long_text($item) {
  return is_long_string($item['text']);
}

function summary($item) {
  return summary_string($item['text']);
}

function full($item) {
  return $item['text'];
}

require "$page->branch/index.html";

$page->module('3down');
$page->output();
    
?>
