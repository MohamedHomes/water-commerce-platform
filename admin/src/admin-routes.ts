import type { AdminMessage } from './i18n';

export const adminNavigation = [
    { path: '/', label: 'dashboard', group: 'overview' },
    { path: '/orders', label: 'orders', group: 'operations' },
    { path: '/deliveries', label: 'deliveries', group: 'operations' },
    { path: '/products', label: 'products', group: 'catalog' },
    { path: '/categories', label: 'categories', group: 'catalog' },
    { path: '/brands', label: 'brands', group: 'catalog' },
    { path: '/inventory', label: 'inventory', group: 'catalog' },
    { path: '/promotions', label: 'promotions', group: 'marketing' },
    { path: '/reviews', label: 'reviews', group: 'marketing' },
] as const satisfies readonly { path: string; label: AdminMessage; group: string }[];

export type AdminPath = (typeof adminNavigation)[number]['path'] | '/catalog-terms';

export function normalizeAdminPath(pathname: string): string {
    if (pathname === '/') return pathname;
    return pathname.replace(/\/+$/, '') || '/';
}

export function isAdminPath(pathname: string): pathname is AdminPath {
    const path = normalizeAdminPath(pathname);
    return adminNavigation.some((route) => route.path === path) || path === '/catalog-terms';
}

export function pageTitleKey(pathname: string): AdminMessage {
    const path = normalizeAdminPath(pathname);
    if (path === '/catalog-terms') return 'catalogTerms';
    return adminNavigation.find((route) => route.path === path)?.label ?? 'pageNotFound';
}
