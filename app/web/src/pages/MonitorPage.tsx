import { useState } from "react";
import { Link, useNavigate, useParams } from "react-router";
import { api } from "../api";
import { StatusBadge } from "../components/StatusBadge";
import { StatusStrip } from "../components/StatusStrip";
import { day, millis, percent, timeAgo } from "../format";
import { useData } from "../useData";

export function MonitorPage() {
  const id = Number(useParams().id);
  const navigate = useNavigate();
  const [deleteError, setDeleteError] = useState<string | null>(null);

  const monitors = useData(api.listMonitors, 15_000);
  const results = useData(() => api.listResults(id), 15_000);
  const daily = useData(() => api.listDaily(id), 60_000);

  const monitor = monitors.data?.find((m) => m.id === id);

  if (monitors.data && !monitor) {
    return (
      <div className="card">
        <p>This monitor does not exist.</p>
        <Link to="/">Back to all monitors</Link>
      </div>
    );
  }
  if (!monitor) {
    return <p className="muted">{monitors.error ?? "Loading…"}</p>;
  }

  async function remove() {
    if (!monitor || !window.confirm(`Stop watching "${monitor.name}"? Its history is deleted too.`)) return;
    try {
      await api.deleteMonitor(monitor.id);
      navigate("/");
    } catch (err) {
      setDeleteError(err instanceof Error ? err.message : String(err));
    }
  }

  return (
    <>
      <Link to="/" className="small">
        ← All monitors
      </Link>

      <section className="summary">
        <h1>
          {monitor.name} <StatusBadge status={monitor.status} />
        </h1>
        <p className="muted">
          <a href={monitor.url} target="_blank" rel="noreferrer">
            {monitor.url}
          </a>{" "}
          · expects status {monitor.expected_status}
        </p>
      </section>

      <div className="stats">
        <div className="card stat">
          <span className="muted small">Last check</span>
          <strong>{timeAgo(monitor.last_checked_at)}</strong>
        </div>
        <div className="card stat">
          <span className="muted small">Response time</span>
          <strong>{millis(monitor.last_latency_ms)}</strong>
        </div>
        <div className="card stat">
          <span className="muted small">Uptime (24 h)</span>
          <strong>{percent(monitor.uptime_24h)}</strong>
        </div>
      </div>

      {monitor.status === "down" && monitor.last_error && (
        <p className="error">Last error: {monitor.last_error}</p>
      )}

      <section className="card">
        <h2>Recent checks</h2>
        {results.data && <StatusStrip results={results.data} />}
        {results.error && <p className="error">{results.error}</p>}
      </section>

      <section className="card">
        <h2>Daily summary</h2>
        {daily.data && daily.data.length === 0 && (
          <p className="muted">The rollup job has not run yet. Locally it runs every 5 minutes.</p>
        )}
        {daily.data && daily.data.length > 0 && (
          <table>
            <thead>
              <tr>
                <th>Day</th>
                <th>Checks</th>
                <th>Uptime</th>
                <th>Avg response</th>
              </tr>
            </thead>
            <tbody>
              {daily.data.map((d) => (
                <tr key={d.day}>
                  <td>{day(d.day)}</td>
                  <td>{d.checks}</td>
                  <td>{percent(d.uptime_pct)}</td>
                  <td>{millis(d.avg_latency_ms)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>

      <section className="card danger-zone">
        <button className="danger" onClick={remove}>
          Delete monitor
        </button>
        {deleteError && <p className="error">{deleteError}</p>}
      </section>
    </>
  );
}
