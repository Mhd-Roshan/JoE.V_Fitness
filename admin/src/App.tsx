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
import RequireAuth from "./components/RequireAuth";

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/" element={<RequireAuth> <Dashboard /> </RequireAuth>} />
        <Route path="/users" element={<RequireAuth> <Users /> </RequireAuth>} />
        <Route path="/users/:id" element={<RequireAuth> <UserProfile /> </RequireAuth>} />
        <Route path="/users/:id/sessions" element={<RequireAuth> <SessionHistory /> </RequireAuth>} />
        <Route path="/users/:id/diet-plan" element={<RequireAuth> <AssignDietPlan /> </RequireAuth>} />
        <Route path="/trainers" element={<RequireAuth> <Trainers /> </RequireAuth>} />
        <Route path="/trainers/add" element={<RequireAuth> <AddTrainer /> </RequireAuth>} />
        <Route path="/chats" element={<RequireAuth> <Chats /> </RequireAuth>} />
        <Route path="/sessions" element={<RequireAuth> <Sessions /> </RequireAuth>} />
        <Route path="/sessions/media" element={<RequireAuth> <MediaLibrary /> </RequireAuth>} />
        <Route path="/packages" element={<RequireAuth> <Packages /> </RequireAuth>} />
        <Route path="/packages/add" element={<RequireAuth> <AddPackage /> </RequireAuth>} />
        <Route path="/packages/edit/:id" element={<RequireAuth> <EditPackage /> </RequireAuth>} />
        <Route path="/packages/addons" element={<RequireAuth> <ManageAddons /> </RequireAuth>} />
        <Route path="/subscriptions" element={<RequireAuth> <Subscriptions /> </RequireAuth>} />
        <Route path="/diet-plans" element={<RequireAuth> <DietPlans /> </RequireAuth>} />
        <Route path="/diet-plans/library" element={<RequireAuth> <BrowseLibrary /> </RequireAuth>} />
        <Route path="/diet-plans/activity" element={<RequireAuth> <DietActivityLog /> </RequireAuth>} />
        <Route path="/diet-plans/add" element={<RequireAuth> <CreateDietTemplate /> </RequireAuth>} />
        <Route path="/diet-plans/edit/:id" element={<RequireAuth> <CreateDietTemplate /> </RequireAuth>} />
        <Route path="/diet-plans/view/:id" element={<RequireAuth> <TemplateDetails /> </RequireAuth>} />
        <Route path="/reports" element={<RequireAuth> <Reports /> </RequireAuth>} />
        <Route path="/settings" element={<RequireAuth> <Settings /> </RequireAuth>} />
        <Route path="/payments" element={<RequireAuth> <Payments /> </RequireAuth>} />
        <Route path="/notifications" element={<RequireAuth> <Notifications /> </RequireAuth>} />


        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter >
  );
}

export default App;