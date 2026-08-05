import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import Login from "./pages/Login";
import Dashboard from "./pages/Dashboard";
import Users from "./pages/Users";
import UserProfile from "./pages/UserProfile";
import SessionHistory from "./pages/SessionHistory";
import AssignDietPlan from "./pages/AssignDietPlan";
import Trainers from "./pages/Trainers";
import AddTrainer from "./pages/AddTrainer";
import Chats from "./pages/Chats";
import Sessions from "./pages/Sessions";
import MediaLibrary from "./pages/MediaLibrary";
import Packages from "./pages/Packages";
import AddPackage from "./pages/AddPackage";
import EditPackage from "./pages/EditPackage";
import ManageAddons from "./pages/ManageAddons";
import Subscriptions from "./pages/Subscriptions";
import DietPlans from "./pages/DietPlans";
import BrowseLibrary from "./pages/BrowseLibrary";
import DietActivityLog from "./pages/DietActivityLog";
import CreateDietTemplate from "./pages/CreateDietTemplate";
import TemplateDetails from "./pages/TemplateDetails";
import Payments from "./pages/Payments";
import Reports from "./pages/Reports";
import Settings from "./pages/Settings";
import Notifications from "./pages/Notifications";

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/" element={<Dashboard />} />
        <Route path="/users" element={<Users />} />
        <Route path="/users/:id" element={<UserProfile />} />
        <Route path="/users/:id/sessions" element={<SessionHistory />} />
        <Route path="/users/:id/diet-plan" element={<AssignDietPlan />} />
        <Route path="/trainers" element={<Trainers />} />
        <Route path="/trainers/add" element={<AddTrainer />} />
        <Route path="/chats" element={<Chats />} />
        <Route path="/sessions" element={<Sessions />} />
        <Route path="/sessions/media" element={<MediaLibrary />} />
        <Route path="/packages" element={<Packages />} />
        <Route path="/packages/add" element={<AddPackage />} />
        <Route path="/packages/edit/:id" element={<EditPackage />} />
        <Route path="/packages/addons" element={<ManageAddons />} />
        <Route path="/subscriptions" element={<Subscriptions />} />
        <Route path="/diet-plans" element={<DietPlans />} />
        <Route path="/diet-plans/library" element={<BrowseLibrary />} />
        <Route path="/diet-plans/activity" element={<DietActivityLog />} />
        <Route path="/diet-plans/add" element={<CreateDietTemplate />} />
        <Route path="/diet-plans/edit/:id" element={<CreateDietTemplate />} />
        <Route path="/diet-plans/view/:id" element={<TemplateDetails />} />
        <Route path="/reports" element={<Reports />} />
        <Route path="/settings" element={<Settings />} />
        <Route path="/payments" element={<Payments />} />
        <Route path="/notifications" element={<Notifications />} />


        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;