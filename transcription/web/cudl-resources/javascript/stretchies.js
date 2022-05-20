"use strict";
$(document).ready(function () {
    $('span.stretchyVertical, span.stretchyHorizontal').each(function (index, j) {
        var elem = $(j);
        var classList = elem.attr('class').split(' ');
        var character = elem.html();
        var idVal = "stretchy" + index;
        var txt = '';
        var size = 0;
        if (classList.includes('stretchyVertical')) {
            size = Math.floor(elem.closest("td").innerHeight());
            txt = '<math id="' + idVal + '" xmlns="http://www.w3.org/1998/Math/MathML"><mo stretchy="true" minsize="' + size + 'px">' + character + '</mo></math>';
        }
        else if (classList.includes('stretchyHorizontal')) {
            size = elem.closest("td").width();
            txt = '<math id="' + idVal + '" xmlns="http://www.w3.org/1998/Math/MathML"><munder accentunder="true"><mspace width="' + size + 'px" /><mo stretchy="true">' + character + '</mo></munder></math>';
        }
        elem.html(txt);
        MathJax.Hub.Queue(["Typeset", MathJax.Hub, '"' + idVal + '"']);
    });
});
