import type { MonitorStatus } from "../api";

const labels: Record<MonitorStatus, string> = {
  up: "Up",
  down: "Down",
  unknown: "Waiting",
};

export function StatusBadge({ status }: { status: MonitorStatus }) {
  return <span className={`badge badge-${status}`}>{labels[status]}</span>;
}
