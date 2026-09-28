import { useState, type FormEvent } from "react";
import { api } from "../api";

export function AddMonitorForm({ onAdded }: { onAdded: () => void }) {
  const [name, setName] = useState("");
  const [url, setUrl] = useState("");
  const [expectedStatus, setExpectedStatus] = useState("200");
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);
    try {
      await api.createMonitor({
        name,
        url,
        expected_status: Number(expectedStatus) || 200,
      });
      setName("");
      setUrl("");
      setExpectedStatus("200");
      onAdded();
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  }

  return (
    <form className="card form" onSubmit={submit}>
      <h2>Add a monitor</h2>
      <label>
        Name
        <input value={name} onChange={(e) => setName(e.target.value)} placeholder="My website" required />
      </label>
      <label>
        URL
        <input
          value={url}
          onChange={(e) => setUrl(e.target.value)}
          placeholder="https://example.com"
          type="url"
          required
        />
      </label>
      <label>
        Expected status
        <input
          value={expectedStatus}
          onChange={(e) => setExpectedStatus(e.target.value)}
          type="number"
          min={100}
          max={599}
        />
      </label>
      {error && <p className="error">{error}</p>}
      <button type="submit" disabled={saving}>
        {saving ? "Adding…" : "Add monitor"}
      </button>
    </form>
  );
}
