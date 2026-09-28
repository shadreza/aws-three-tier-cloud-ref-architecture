// Every call to the backend lives in this file.
// The paths start with /api. Vite (locally) or CloudFront (on AWS) sends
// them to the Go API.

export type MonitorStatus = "up" | "down" | "unknown";

export type Monitor = {
  id: number;
  name: string;
  url: string;
  expected_status: number;
  created_at: string;
  status: MonitorStatus;
  last_checked_at: string | null;
  last_latency_ms: number | null;
  last_error?: string;
  uptime_24h: number | null;
};

export type CheckResult = {
  id: number;
  monitor_id: number;
  checked_at: string;
  is_up: boolean;
  status_code: number;
  latency_ms: number;
  error?: string;
};

export type DailySummary = {
  monitor_id: number;
  day: string;
  checks: number;
  up_checks: number;
  uptime_pct: number;
  avg_latency_ms: number;
};

export type Report = {
  name: string;
  day: string;
};

export type NewMonitor = {
  name: string;
  url: string;
  expected_status: number;
};

// The admin token is kept in the browser so you only type it once.
const TOKEN_KEY = "uptime.adminToken";

export function getToken(): string {
  try {
    return localStorage.getItem(TOKEN_KEY) ?? "";
  } catch {
    return "";
  }
}

export function saveToken(token: string) {
  try {
    localStorage.setItem(TOKEN_KEY, token);
  } catch {
    // Private windows can block storage. The app still works, you just
    // have to type the token again next time.
  }
}

function authHeader(): Record<string, string> {
  return { Authorization: `Bearer ${getToken()}` };
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(path, init);
  if (!res.ok) {
    const body = await res.json().catch(() => null);
    throw new Error(body?.error ?? `Request failed (${res.status})`);
  }
  if (res.status === 204) {
    return undefined as T;
  }
  return res.json() as Promise<T>;
}

export const api = {
  listMonitors: () => request<Monitor[]>("/api/monitors"),

  createMonitor: (input: NewMonitor) =>
    request<Monitor>("/api/monitors", {
      method: "POST",
      headers: { ...authHeader(), "Content-Type": "application/json" },
      body: JSON.stringify(input),
    }),

  deleteMonitor: (id: number) =>
    request<void>(`/api/monitors/${id}`, {
      method: "DELETE",
      headers: authHeader(),
    }),

  listResults: (id: number, limit = 60) =>
    request<CheckResult[]>(`/api/monitors/${id}/results?limit=${limit}`),

  listDaily: (id: number) => request<DailySummary[]>(`/api/monitors/${id}/daily`),

  listReports: () => request<Report[]>("/api/reports"),

  reportUrl: (name: string) => `/api/reports/${encodeURIComponent(name)}`,
};
