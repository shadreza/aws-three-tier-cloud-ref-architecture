import { useState } from "react";
import { getToken, saveToken } from "../api";

// Adding and deleting monitors needs the admin token. Locally it is
// "local-dev-token" (see compose.yaml).
export function TokenBox() {
  const [token, setToken] = useState(getToken);
  const [saved, setSaved] = useState(false);

  return (
    <form
      className="token-box"
      onSubmit={(e) => {
        e.preventDefault();
        saveToken(token);
        setSaved(true);
      }}
    >
      <input
        type="password"
        value={token}
        onChange={(e) => {
          setToken(e.target.value);
          setSaved(false);
        }}
        placeholder="Admin token"
        aria-label="Admin token"
      />
      <button type="submit">{saved ? "Saved" : "Save"}</button>
    </form>
  );
}
