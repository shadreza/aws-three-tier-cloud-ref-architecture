import type { CheckResult } from "../api";

// A row of small bars, one per check, oldest on the left. Green means the
// site answered as expected, red means it did not.
export function StatusStrip({ results }: { results: CheckResult[] }) {
  if (results.length === 0) {
    return <p className="muted">No checks yet. The first one runs within a minute.</p>;
  }

  const oldestFirst = [...results].reverse();
  return (
    <div className="strip" aria-label="Recent checks, oldest first">
      {oldestFirst.map((r) => (
        <span
          key={r.id}
          className={r.is_up ? "strip-bar up" : "strip-bar down"}
          title={`${new Date(r.checked_at).toLocaleString()}: ${
            r.is_up ? `up, ${r.latency_ms} ms` : r.error || "down"
          }`}
        />
      ))}
    </div>
  );
}
