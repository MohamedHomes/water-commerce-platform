function App() {
    return (
        <main className="app-shell">
            <header className="topbar">
                <div>
                    <p className="eyebrow">Operations dashboard</p>
                    <h1>AquaFlow Admin</h1>
                </div>
            </header>

            <section className="grid">
                <article className="card metric">
                    <span>Orders</span>
                    <strong>1,248</strong>
                    <small>+12.4% vs last week</small>
                </article>
                <article className="card metric">
                    <span>Revenue</span>
                    <strong>SR 18,420</strong>
                    <small>+8.1% vs last week</small>
                </article>
                <article className="card metric">
                    <span>Fleet</span>
                    <strong>34 active</strong>
                    <small>6 pending dispatch</small>
                </article>
            </section>

            <section className="card panel">
                <h2>Operational overview</h2>
                <ul>
                    <li>Orders</li>
                    <li>Inventory</li>
                    <li>Delivery zones</li>
                    <li>Promotions</li>
                    <li>Payments</li>
                </ul>
            </section>
        </main>
    );
}

export default App;
