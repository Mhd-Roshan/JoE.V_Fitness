import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "boxicons/css/boxicons.min.css";
import App from "./App";
import { LanguageProvider } from "./contexts/LanguageContext";
import "./index.css";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <LanguageProvider>
      <App />
    </LanguageProvider>
  </StrictMode>
);