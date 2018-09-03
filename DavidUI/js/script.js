//---------------function for including other pages in home page with iframe tag-----------------

function MyFunction(url) {
    document.getElementById('homePage').src = url;
}
//------------------- function for submenu ------------------------------------------------------

var ddmenuitem = 0;
function jsddm_open() {
    jsddm_close();
    ddmenuitem = $(this).find('ul.current').css('display', 'block');
}
function jsddm_close() {
    if (ddmenuitem) ddmenuitem.css('display', 'none');
}
$(document).ready(function () {
    $('.main-nav > ul > li').bind('click', jsddm_open)
    $('.main-nav > ul > li > a').click(function () {
        if ($(this).attr('class') != 'active') {
            $('.main-nav ul li a').removeClass('active').css('background-color', 'dimgrey');
            $(this).addClass('active').css('background-color', 'midnightblue');
        }

        if ($('.main-nav > ul > li > ul > li > a') == 'active') {
            $(this).css('background-color', 'midnightblue');
            $('.main-nav > ul > li > ul > li > a').css('color', 'midnightblue');
        }

        $('.main-nav > ul > li > ul > li > a').click(function () {

            if ($(this).attr('class') != 'active') {
                $('.main-nav ul li a').removeClass('active').css('color', 'white');
                $(this).addClass('active').css('color', 'midnightblue');
            }
        });

        $('.main-nav ul li ul li a').css('color', 'white');
    });

});
