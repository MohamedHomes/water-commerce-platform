import { ReactNode, useState } from 'react';
import { adminNavigation } from './admin-routes';
import { AdminLanguage, AdminMessage } from './i18n';

interface AdminLayoutProps {
    pathname: string;
    title: string;
    language: AdminLanguage;
    administrator: string;
    t: (key: AdminMessage) => string;
    onNavigate: (path: string) => void;
    onLanguageChange: () => void;
    onSignOut: () => void;
    children: ReactNode;
}

const iconByPath: Record<string, string> = {
    '/': 'M3 10.5 12 3l9 7.5M5 9v11h14V9M9 20v-6h6v6',
    '/orders': 'M5 4h14v16H5zM8 8h8M8 12h8M8 16h5',
    '/deliveries': 'M3 7h12v11H3zM15 11h4l2 3v4h-6zM7 18a2 2 0 1 0 0 .1M18 18a2 2 0 1 0 0 .1',
    '/products': 'M4 7h16l-1 13H5L4 7ZM8 7a4 4 0 0 1 8 0',
    '/categories': 'M4 4h7v7H4zM14 4h6v7h-6zM4 14h7v6H4zM14 14h6v6h-6z',
    '/brands': 'M4 5h16v14H4zM8 9h8M8 13h5',
    '/inventory': 'M4 7h16v13H4zM3 4h18M8 11h8M8 15h5',
    '/promotions': 'm12 3 2.8 5.7 6.2.9-4.5 4.4 1.1 6.2L12 17.3 6.4 20.2l1.1-6.2L3 9.6l6.2-.9L12 3Z',
    '/reviews': 'm12 3 2.8 5.7 6.2.9-4.5 4.4 1.1 6.2L12 17.3 6.4 20.2l1.1-6.2L3 9.6l6.2-.9L12 3Z',
};

function NavigationIcon({ path }: { path: string }) {
    return (
        <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor"
            strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
            <path d={iconByPath[path] ?? iconByPath['/']} />
        </svg>
    );
}

export function AdminLayout({
    pathname,
    title,
    language,
    administrator,
    t,
    onNavigate,
    onLanguageChange,
    onSignOut,
    children,
}: AdminLayoutProps) {
    const [collapsed, setCollapsed] = useState(
        () => localStorage.getItem('aquaflow-admin-sidebar-collapsed') === 'true',
    );
    const [mobileOpen, setMobileOpen] = useState(false);

    function toggleCollapsed() {
        setCollapsed((value) => {
            localStorage.setItem('aquaflow-admin-sidebar-collapsed', String(!value));
            return !value;
        });
    }

    function navigate(path: string) {
        onNavigate(path);
        setMobileOpen(false);
    }

    const groups = [
        { id: 'overview', label: t('overview') },
        { id: 'operations', label: t('operations') },
        { id: 'catalog', label: t('catalog') },
        { id: 'marketing', label: t('marketing') },
    ];

    return (
        <div className={`admin-layout${collapsed ? ' is-collapsed' : ''}${mobileOpen ? ' mobile-open' : ''}`}
            data-language={language}>
            {mobileOpen && <button className="sidebar-backdrop" aria-label={t('closeMenu')} onClick={() => setMobileOpen(false)} />}
            <aside className="sidebar" aria-label={t('mainNavigation')}>
                <div className="brand-lockup">
                    <span className="brand-mark" aria-hidden="true">A</span>
                    <span className="brand-name">AquaFlow<span>ADMIN</span></span>
                    <button className="icon-button sidebar-collapse" aria-label={collapsed ? t('expandSidebar') : t('collapseSidebar')}
                        title={collapsed ? t('expandSidebar') : t('collapseSidebar')} onClick={toggleCollapsed}>
                        <span aria-hidden="true">{collapsed ? '»' : '«'}</span>
                    </button>
                </div>
                <nav>
                    {groups.map((group) => (
                        <div className="nav-group" key={group.id}>
                            <p className="nav-group-title">{group.label}</p>
                            {adminNavigation.filter((item) => item.group === group.id).map((item) => {
                                const active = pathname === item.path
                                    || (item.path === '/categories' && pathname === '/catalog-terms');
                                return (
                                    <a key={item.path} href={item.path} className={`nav-link${active ? ' active' : ''}`}
                                        aria-current={active ? 'page' : undefined} title={collapsed ? t(item.label) : undefined}
                                        onClick={(event) => {
                                            if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
                                            event.preventDefault();
                                            navigate(item.path);
                                        }}>
                                        <NavigationIcon path={item.path} />
                                        <span className="nav-label">{t(item.label)}</span>
                                    </a>
                                );
                            })}
                        </div>
                    ))}
                </nav>
                <div className="sidebar-footer">
                    <span className="sidebar-status-dot" />
                    <span>{t('adminWorkspace')}</span>
                </div>
            </aside>
            <div className="main-column">
                <header className="admin-header">
                    <button className="icon-button mobile-menu-button" aria-label={t('openMenu')} onClick={() => setMobileOpen(true)}>☰</button>
                    <div className="header-heading">
                        <nav className="breadcrumbs" aria-label={t('breadcrumbs')}>
                            <a href="/" onClick={(event) => { event.preventDefault(); navigate('/'); }}>{t('dashboard')}</a>
                            {pathname !== '/' && <><span aria-hidden="true">/</span><span>{title}</span></>}
                        </nav>
                        <h1>{title}</h1>
                    </div>
                    <div className="header-actions">
                        <button className="language-toggle" type="button" onClick={onLanguageChange}>{t('language')}</button>
                        <div className="account-chip">
                            <span className="account-avatar" aria-hidden="true">{administrator.slice(0, 1).toUpperCase()}</span>
                            <span className="account-email">{administrator}</span>
                        </div>
                        <button className="button button-quiet signout-button" onClick={onSignOut}>{t('signOut')}</button>
                    </div>
                </header>
                <main className="page-content">{children}</main>
            </div>
        </div>
    );
}
