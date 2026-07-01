// Attach to any element with class "nav-logout" to sign out and redirect to Home
document.querySelectorAll('.nav-logout').forEach(el => {
    el.addEventListener('click', async (e) => {
        e.preventDefault();
        await sb.auth.signOut();

        // Find the root of the project by locating the GamingLeague folder in the URL
        const path = window.location.pathname;
        const marker = '/GamingLeague/';
        const rootIndex = path.indexOf(marker);

        if (rootIndex !== -1) {
            // Build absolute path to Home.html from the project root
            window.location.href = window.location.origin + path.substring(0, rootIndex + marker.length) + 'Home.html';
        } else {
            // Fallback: go up to the nearest root we can find
            window.location.href = 'Home.html';
        }
    });
});
