import { api } from "../api";
import { useData } from "../useData";

export function ReportsPage() {
  const { data: reports, error } = useData(api.listReports, 60_000);

  return (
    <>
      <section className="summary">
        <h1>Daily reports</h1>
        <p className="muted">
          The rollup job writes one CSV file per day. Locally it runs every 5 minutes. On AWS it will
          run once a night and save the files to S3.
        </p>
      </section>

      {error && <p className="error">Could not load reports: {error}</p>}

      {reports && reports.length === 0 && (
        <div className="card empty">
          <p>
            No reports yet. Wait a few minutes, or run <code>make rollup</code> to make one now.
          </p>
        </div>
      )}

      {reports && reports.length > 0 && (
        <ul className="card report-list">
          {reports.map((r) => (
            <li key={r.name}>
              <span>{r.day}</span>
              <a href={api.reportUrl(r.name)}>Download CSV</a>
            </li>
          ))}
        </ul>
      )}
    </>
  );
}
