/* to make lines scroll instead of wrap */
/* from http://stackoverflow.com/a/23393920 */

.highlight pre code * {
  white-space: nowrap;    // this sets all children inside to nowrap
}

.highlight pre {
  overflow-x: auto;       // this sets the scrolling in x
}

.highlight pre code {
  white-space: pre;       // forces <code> to respect <pre> formatting
}


/*
 * GitHub style for Pygments syntax highlighter, for use with Jekyll
 * Courtesy of GitHub.com
 */

.highlight pre, pre, .highlight .hll { background-color: #f8f8f8; border: 1px solid #ccc; padding: 6px 10px; border-radius: 3px; }
.highlight .c { color: #999988; font-style: italic; }
.highlight .err { color: #a61717; background-color: #e3d2d2; }
.highlight .k { font-weight: bold; }
.highlight .o { font-weight: bold; }
.highlight .cm { color: #999988; font-style: italic; }
.highlight .cp { color: #999999; font-weight: bold; }
.highlight .c1 { color: #999988; font-style: italic; }
.highlight .cs { color: #999999; font-weight: bold; font-style: italic; }
.highlight .gd { color: #000000; background-color: #ffdddd; }
.highlight .gd .x { color: #000000; background-color: #ffaaaa; }
.highlight .ge { font-style: italic; }
.highlight .gr { color: #aa0000; }
.highlight .gh { color: #999999; }
.highlight .gi { color: #000000; background-color: #ddffdd; }
.highlight .gi .x { color: #000000; background-color: #aaffaa; }
.highlight .go { color: #888888; }
.highlight .gp { color: #555555; }
.highlight .gs { font-weight: bold; }
.highlight .gu { color: #800080; font-weight: bold; }
.highlight .gt { color: #aa0000; }
.highlight .kc { font-weight: bold; }
.highlight .kd { font-weight: bold; }
.highlight .kn { font-weight: bold; }
.highlight .kp { font-weight: bold; }
.highlight .kr { font-weight: bold; }
.highlight .kt { color: #445588; font-weight: bold; }
.highlight .m { color: #009999; }
.highlight .s { color: #dd1144; }
.highlight .n { color: #333333; }
.highlight .na { color: teal; }
.highlight .nb { color: #0086b3; }
.highlight .nc { color: #445588; font-weight: bold; }
.highlight .no { color: teal; }
.highlight .ni { color: purple; }
.highlight .ne { color: #990000; font-weight: bold; }
.highlight .nf { color: #990000; font-weight: bold; }
.highlight .nn { color: #555555; }
.highlight .nt { color: navy; }
.highlight .nv { color: teal; }
.highlight .ow { font-weight: bold; }
.highlight .w { color: #bbbbbb; }
.highlight .mf { color: #009999; }
.highlight .mh { color: #009999; }
.highlight .mi { color: #009999; }
.highlight .mo { color: #009999; }
.highlight .sb { color: #dd1144; }
.highlight .sc { color: #dd1144; }
.highlight .sd { color: #dd1144; }
.highlight .s2 { color: #dd1144; }
.highlight .se { color: #dd1144; }
.highlight .sh { color: #dd1144; }
.highlight .si { color: #dd1144; }
.highlight .sx { color: #dd1144; }
.highlight .sr { color: #009926; }
.highlight .s1 { color: #dd1144; }
.highlight .ss { color: #990073; }
.highlight .bp { color: #999999; }
.highlight .vc { color: teal; }
.highlight .vg { color: teal; }
.highlight .vi { color: teal; }
.highlight .il { color: #009999; }
.highlight .gc { color: #999; background-color: #EAF2F5; }
