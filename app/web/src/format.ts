export function timeAgo(iso: string | null): string {
  if (!iso) return "never";
  const seconds = Math.round((Date.now() - new Date(iso).getTime()) / 1000);
  if (seconds < 5) return "just now";
  if (seconds < 60) return `${seconds}s ago`;
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `${minutes} min ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours} h ago`;
  return new Date(iso).toLocaleDateString();
}

export function percent(value: number | null): string {
  return value === null ? "–" : `${value.toFixed(1)}%`;
}

export function millis(value: number | null): string {
  return value === null ? "–" : `${value} ms`;
}

export function day(iso: string): string {
  return iso.slice(0, 10);
}
