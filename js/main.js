// Hamburger menu toggle — shared across all pages
(function () {
    const toggle = document.querySelector('.nav-toggle');
    const navLinks = document.querySelector('.nav-links');
    if (!toggle || !navLinks) return;
    toggle.addEventListener('click', () => {
        const open = navLinks.classList.toggle('nav-open');
        toggle.setAttribute('aria-expanded', open);
    });
})();
