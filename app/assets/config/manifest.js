// app/assets/config/manifest.js

// ----------------------------------------------------------------------
// 1. DIRECTORY LINKS (Source Files)
// ----------------------------------------------------------------------

// Link source images and fonts for Sprockets lookup
//= link_tree ../images
//= link_tree ../fonts

// Link JavaScript source folders

//= link_tree ../../../vendor/javascript .js


// ----------------------------------------------------------------------
// 2. TAILWIND/BUILD OUTPUT (Final CSS)
// ----------------------------------------------------------------------

// This handles the link for application.css (which Tailwind builds).
//= link_tree ../builds

// REMOVE THIS: Linking the source directory causes conflict with ../builds
//- link_tree ../tailwind .css 


// ----------------------------------------------------------------------
// 3. FINAL ENTRY POINTS (The files the browser requests)
// ----------------------------------------------------------------------


// Link the primary application CSS file (This is now linked from the '../builds' directory)
//= link application.css

// Link Active Admin assets
//= link active_admin.css
//= link active_admin.js

// Link flowbite index (often needed for JS components)
//= link flowbite/lib/cjs/index.js

// ----------------------------------------------------------------------
// 4. ADMIN ASSETS
// ----------------------------------------------------------------------
//= link admin_assets/application.css
//= link user_assets/application.css
//= link_tree ../../javascript .js
//= link_tree ../../../vendor/javascript .js

// import echarts and screenfull for admin dashboard charts
//= link echarts/dist/echarts.js