// ─────────────────────────────────────────────────────────────────────
//  auth-guard.js
//  Checks for an active session; redirects to Login if none found.
//  Populates .user-greeting with the user's first name.
//  For admin users, injects a view-toggle button next to the nav-brand.
//
//  Optional — require admin role (declare BEFORE including this file):
//    <script>const REQUIRE_ADMIN = true;</script>
// ─────────────────────────────────────────────────────────────────────

(async function () {
    const { data: { session } } = await sb.auth.getSession();

    if (!session) {
        const path    = window.location.pathname;
        const marker  = '/GamingLeague/';
        const rootIdx = path.indexOf(marker);
        const base    = rootIdx !== -1
            ? window.location.origin + path.substring(0, rootIdx + marker.length)
            : window.location.origin + '/';
        window.location.replace(base + 'Login.html');
        return;
    }

    // Fetch full profile
    const { data: profile } = await sb
        .from('users')
        .select('name, role')
        .eq('id', session.user.id)
        .single();

    // Admin guard — bounce non-admins back to Hub
    if (typeof REQUIRE_ADMIN !== 'undefined' && REQUIRE_ADMIN) {
        if (!profile || profile.role !== 'admin') {
            const path    = window.location.pathname;
            const marker  = '/GamingLeague/';
            const rootIdx = path.indexOf(marker);
            const base    = rootIdx !== -1
                ? window.location.origin + path.substring(0, rootIdx + marker.length)
                : window.location.origin + '/';
            window.location.replace(base + 'Hub.html');
            return;
        }
    }

    // Populate greeting(s)
    if (profile) {
        document.querySelectorAll('.user-greeting').forEach(el => {
            el.textContent = 'HI, ' + profile.name.toUpperCase();
        });
    }

    // ── Admin navbar theme ────────────────────────────────────────────
    // Adds .navbar-admin to the navbar when the logged-in user is an admin,
    // giving it the dark background + white text treatment.
    if (profile?.role === 'admin') {
        const navbar = document.querySelector('.navbar');
        if (navbar) navbar.classList.add('navbar-admin');
    }

    // ── Admin view-toggle button ───────────────────────────────────────
    // Injected next to the nav-brand for admin users on any page.
    // On the Admin page  → button says "USER VIEW"  → goes to Hub
    // On any other page  → button says "ADMIN VIEW" → goes to Admin
    if (profile?.role === 'admin') {
        const brand = document.querySelector('.nav-brand');
        if (brand) {
            const path    = window.location.pathname;
            const marker  = '/GamingLeague/';
            const rootIdx = path.indexOf(marker);
            const base    = rootIdx !== -1
                ? window.location.origin + path.substring(0, rootIdx + marker.length)
                : window.location.origin + '/';

            const isAdminPage = path.toLowerCase().includes('/admin/');
            const label = isAdminPage ? 'USER VIEW' : 'ADMIN VIEW';
            const target = isAdminPage ? base + 'Hub.html' : base + 'Admin/Admin.html';

            const btn = document.createElement('button');
            btn.textContent = label;
            btn.className   = 'admin-toggle-btn';
            btn.setAttribute('aria-label', isAdminPage ? 'Switch to user view' : 'Switch to admin view');
            btn.addEventListener('click', () => { window.location.href = target; });

            brand.insertAdjacentElement('afterend', btn);
        }
    }

    // Expose for pages that need it
    window.currentUser    = session.user;
    window.currentProfile = profile;
})();
