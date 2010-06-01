<?php


require_once "../config/mobi_web_constants.php";
require_once PAGE_HEADER;
require_once LIBDIR . "StellarData.php";
require_once "stellar_lib.php";

function selfURL() {
  return "course.php?id=" . $_REQUEST['id'] . '&back=' . $_REQUEST['back'];
}

$id = $_REQUEST['id'];
$back = $_REQUEST['back'];
$Back = ucwords($back);

$course = StellarData::get_course($id);
$classes = StellarData::get_subjects_with_xref($id);

require "$page->branch/course.html";
$page->output();
    
?>
