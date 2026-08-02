import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import Login from "./pages/Login";

// Placeholder Dashboard until the real one is built
function Dashboard() {
  return (
    <div style={{ padding: 40, fontFamily: "sans-serif" }}>
      <h1 style={{ color: "#00225D" }}>Dashboard</h1>
      <p>You're signed in. Real dashboard content goes here next.</p>
    </div>
  );
}

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/" element={<Dashboard />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;