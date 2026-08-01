/*-----------------------------------------------------------------------------------
    
Template Name: Edufit - Education & Online Course HTML Template
URI: site.com
Description:
EduFit is a modern, responsive HTML template designed specifically for educational websites. Perfect for online courses, universities, and e-learning platforms, EduFit offers a clean and professional design, ensuring a user-friendly experience across all devices. With stunning course displays, customizable layouts, and easy-to-navigate features, EduFit provides all the tools you need to create an engaging and seamless learning experience. Whether you're an instructor, educational institution, or e-learning business, EduFit helps you present your content effectively and attract new learners.
Author: Pixelfit
Author URI: https://themeforest.net/user/pixelfit
Version: 1.0

    Note: This is Main Js file

-----------------------------------------------------------------------------------
    ===================
    Js INDEX
    ===================
    ## Main Menu
    ## Document Ready
    ## Nav Overlay
    ## Preloader
    ## Sticky
    ## Back to top
    ## Magnific-popup js
    ## AOS Js
    
-----------------------------------------------------------------------------------*/

(function($) {
    'use strict';

    //===== Main Menu
    function mainMenu() {
        
        // Variables
        var var_window = $(window),
        navContainer = $('.header-navigation'),
        navbarToggler = $('.navbar-toggler'),
        navMenu = $('.edufit-nav-menu'),
        navMenuLi = $('.edufit-nav-menu ul li ul li'),
        closeIcon = $('.navbar-close');

        // navbar toggler

        navbarToggler.on('click', function() {
            navbarToggler.toggleClass('active');
            navMenu.toggleClass('menu-on');
        });

        // close icon

        closeIcon.on('click', function() {
            navMenu.removeClass('menu-on');
            navbarToggler.removeClass('active');
        });

        // adds toggle button to li items that have children

        navMenu.find("li a").each(function() {
            if ($(this).children('.dd-trigger').length < 1) {
                if ($(this).next().length > 0) {
                    $(this).append('<span class="dd-trigger"><i class="far fa-angle-down"></i></span>')
                }
            }
        });
        
        // expands the dropdown menu on each click

        navMenu.find(".dd-trigger").on('click', function(e) {
            e.preventDefault();
            $(this).parent().parent().siblings().children('ul.sub-menu').slideUp();
            $(this).parent().next('ul.sub-menu').stop(!0, !0).slideToggle(350);
            $(this).toggleClass('sub-menu-open')
        });

    };

    

    //===== Offcanvas Overlay

    $(".navbar-toggler, .offcanvas__overlay, .navbar-close").on('click', function (e) {
        $(".offcanvas__overlay").toggleClass("overlay-open");
    });
    $(".offcanvas__overlay").on('click', function (e) {
        $(".navbar-toggler").removeClass("active");
        $(".edufit-nav-menu").removeClass("menu-on");
    }); 
    $(".panel-close-btn, .navbar-close").on("click", function() {
        $(".offcanvas__overlay").removeClass("overlay-open");
    });

    //===== Preloader
    
    $(window).on('load', function(event) {
        $('.preloader').delay(500).fadeOut('500');
    })
    
    //===== Sticky

    $(window).on('scroll', function(event) {
        var scroll = $(window).scrollTop();
        if (scroll < 100) {
            $(".header-navigation").removeClass("sticky");
        } else {
            $(".header-navigation").addClass("sticky");
        }
    });

    //===== Back to top
    
    function backToTop(){
        $(window).on('scroll', function(event) {
            if ($(this).scrollTop() > 600) {
                $('.back-to-top').fadeIn(200)
            } else {
                $('.back-to-top').fadeOut(200)
            }
        });
        $('.back-to-top').on('click', function(event) {
            event.preventDefault();
            $('html, body').animate({ scrollTop: 0 }, { duration: 500, easing: 'swing' });
        });
    }
    

    //===== Magnific-popup js

    function magnificPopup(){
        if ($('.video-popup').length){
            $('.video-popup').magnificPopup({
                type: 'iframe',
                removalDelay: 300,
                mainClass: 'mfp-fade'
            });
        }
        if ($('.img-popup').length){
            $(".img-popup").magnificPopup({
                type: "image",
                 gallery: { 
                  enabled: true 
                }
            });
        }
    }
    
    //====== Aos 
    function aos(){
        AOS.init({
            offset: 0
        });
    }

    
    // Document Ready

    $(document).ready(function() {
        mainMenu();
        magnificPopup();
        aos();
        backToTop();
    });

})(window.jQuery);