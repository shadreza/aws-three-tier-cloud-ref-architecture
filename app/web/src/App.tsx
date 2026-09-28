import { BrowserRouter, NavLink, Route, Routes } from "react-router";
import { TokenBox } from "./components/TokenBox";
import { MonitorPage } from "./pages/MonitorPage";
import { MonitorsPage } from "./pages/MonitorsPage";
import { ReportsPage } from "./pages/ReportsPage";

export function App() {
  return (
    <BrowserRouter>
      <header className="topbar">
        <div className="brand">Uptime</div>
        <nav>
          <NavLink to="/" end>
            Monitors
          </NavLink>
          <NavLink to="/reports">Reports</NavLink>
        </nav>
        <TokenBox />
      </header>

      <main>
        <Routes>
          <Route path="/" element={<MonitorsPage />} />
          <Route path="/monitors/:id" element={<MonitorPage />} />
          <Route path="/reports" element={<ReportsPage />} />
          <Route path="*" element={<p>Page not found.</p>} />
        </Routes>
      </main>
    </BrowserRouter>
  );
}
