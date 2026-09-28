import { Link } from "react-router";
import { api } from "../api";
import { AddMonitorForm } from "../components/AddMonitorForm";
import { StatusBadge } from "../components/StatusBadge";
import { millis, percent, timeAgo } from "../format";
import { useData } from "../useData";

export function MonitorsPage() {
  const { data: monitors, error, reload } = useData(api.listMonitors, 15_000);

  const up = monitors?.filter((m) => m.status === "up").length ?? 0;
  const down = monitors?.filter((m) => m.status === "down").length ?? 0;

  return (
    <>
      <section className="summary">
        <h1>Monitors</h1>
        {monitors && monitors.length > 0 && (
          <p className="muted">
            {monitors.length} watched · <span className="text-up">{up} up</span> ·{" "}
            <span className="text-down">{down} down</span> · refreshes every 15 seconds
          </p>
        )}
      </section>

      {error && <p className="error">Could not load monitors: {error}</p>}
      {!monitors && !error && <p className="muted">Loading…</p>}

      {monitors && monitors.length === 0 && (
        <div className="card empty">
          <h2>Nothing is being watched yet</h2>
          <p>
            Add your first monitor below. Try <code>https://example.com</code>, or run{" "}
            <code>make seed</code> in your terminal to add a few examples.
          </p>
        </div>
      )}

      {monitors && monitors.length > 0 && (
        <table className="card">
          <thead>
            <tr>
              <th>Status</th>
              <th>Name</th>
              <th>Last check</th>
              <th>Response time</th>
              <th>Uptime (24 h)</th>
            </tr>
          </thead>
          <tbody>
            {monitors.map((m) => (
              <tr key={m.id}>
                <td>
                  <StatusBadge status={m.status} />
                </td>
                <td>
                  <Link to={`/monitors/${m.id}`}>{m.name}</Link>
                  <div className="muted small">{m.url}</div>
                </td>
                <td>{timeAgo(m.last_checked_at)}</td>
                <td>{millis(m.last_latency_ms)}</td>
                <td>{percent(m.uptime_24h)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <AddMonitorForm onAdded={reload} />
    </>
  );
}
