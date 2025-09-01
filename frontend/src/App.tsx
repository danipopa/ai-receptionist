import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Link, useLocation } from 'react-router-dom';
import {
  HomeIcon,
  PhoneIcon,
  ChartBarIcon,
  CogIcon,
  UserGroupIcon,
  MicrophoneIcon
} from '@heroicons/react/24/outline';
import toast, { Toaster } from 'react-hot-toast';

// Import components
import Dashboard from './components/Dashboard';
import BusinessList from './components/BusinessList';
import CallHistory from './components/CallHistory';
import ReceptionistConfig from './components/ReceptionistConfig';
import Analytics from './components/Analytics';
import Settings from './components/Settings';
import LiveCalls from './components/LiveCalls';

// API service
import { apiService } from './services/api';

const navigation = [
  { name: 'Dashboard', href: '/', icon: HomeIcon },
  { name: 'Live Calls', href: '/calls', icon: MicrophoneIcon },
  { name: 'Businesses', href: '/businesses', icon: UserGroupIcon },
  { name: 'Call History', href: '/history', icon: PhoneIcon },
  { name: 'Analytics', href: '/analytics', icon: ChartBarIcon },
  { name: 'Settings', href: '/settings', icon: CogIcon },
];

function classNames(...classes: string[]) {
  return classes.filter(Boolean).join(' ');
}

function Sidebar() {
  const location = useLocation();

  return (
    <div className="hidden md:flex md:w-64 md:flex-col md:fixed md:inset-y-0">
      <div className="flex-1 flex flex-col min-h-0 bg-gray-800">
        <div className="flex-1 flex flex-col pt-5 pb-4 overflow-y-auto">
          <div className="flex items-center flex-shrink-0 px-4">
            <div className="flex items-center">
              <MicrophoneIcon className="h-8 w-8 text-indigo-400" />
              <span className="ml-2 text-xl font-bold text-white">AI Receptionist</span>
            </div>
          </div>
          <nav className="mt-5 flex-1 px-2 space-y-1">
            {navigation.map((item) => {
              const current = location.pathname === item.href;
              return (
                <Link
                  key={item.name}
                  to={item.href}
                  className={classNames(
                    current
                      ? 'bg-gray-900 text-white'
                      : 'text-gray-300 hover:bg-gray-700 hover:text-white',
                    'group flex items-center px-2 py-2 text-sm font-medium rounded-md'
                  )}
                >
                  <item.icon
                    className={classNames(
                      current ? 'text-gray-300' : 'text-gray-400 group-hover:text-gray-300',
                      'mr-3 flex-shrink-0 h-6 w-6'
                    )}
                    aria-hidden="true"
                  />
                  {item.name}
                </Link>
              );
            })}
          </nav>
        </div>
        <div className="flex-shrink-0 flex bg-gray-700 p-4">
          <div className="flex items-center">
            <div className="ml-3">
              <p className="text-sm font-medium text-white">Admin User</p>
              <p className="text-xs font-medium text-gray-300">admin@example.com</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function Header() {
  const [systemHealth, setSystemHealth] = useState<any>(null);

  useEffect(() => {
    // Check system health periodically
    const checkHealth = async () => {
      try {
        const health = await apiService.getHealth();
        setSystemHealth(health);
      } catch (error) {
        console.error('Health check failed:', error);
      }
    };

    checkHealth();
    const interval = setInterval(checkHealth, 30000); // Check every 30 seconds

    return () => clearInterval(interval);
  }, []);

  const getHealthStatus = () => {
    if (!systemHealth) return 'unknown';
    return systemHealth.status;
  };

  const getHealthColor = () => {
    switch (getHealthStatus()) {
      case 'healthy':
        return 'bg-green-400';
      case 'degraded':
        return 'bg-yellow-400';
      default:
        return 'bg-red-400';
    }
  };

  return (
    <header className="bg-white shadow-sm border-b border-gray-200">
      <div className="md:hidden pl-1 pt-1 sm:pl-3 sm:pt-3">
        <button
          type="button"
          className="-ml-0.5 -mt-0.5 h-12 w-12 inline-flex items-center justify-center rounded-md text-gray-500 hover:text-gray-900 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-indigo-500"
        >
          <span className="sr-only">Open sidebar</span>
        </button>
      </div>
      <div className="py-4">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 md:px-8">
          <div className="flex items-center justify-between">
            <h1 className="text-2xl font-semibold text-gray-900">AI Receptionist Platform</h1>
            <div className="flex items-center space-x-4">
              <div className="flex items-center">
                <div className={`h-3 w-3 rounded-full ${getHealthColor()}`}></div>
                <span className="ml-2 text-sm text-gray-600 capitalize">
                  System {getHealthStatus()}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </header>
  );
}

function App() {
  useEffect(() => {
    // Initialize the application
    const init = async () => {
      try {
        // You can add initialization logic here
        console.log('AI Receptionist Dashboard initialized');
      } catch (error) {
        console.error('Initialization error:', error);
        toast.error('Failed to initialize application');
      }
    };

    init();
  }, []);

  return (
    <Router>
      <div className="h-screen flex overflow-hidden bg-gray-100">
        <Sidebar />
        <div className="flex flex-col flex-1 md:pl-64">
          <Header />
          <main className="flex-1 overflow-y-auto focus:outline-none">
            <div className="py-6">
              <div className="max-w-7xl mx-auto px-4 sm:px-6 md:px-8">
                <Routes>
                  <Route path="/" element={<Dashboard />} />
                  <Route path="/calls" element={<LiveCalls />} />
                  <Route path="/businesses" element={<BusinessList />} />
                  <Route path="/businesses/:id/config" element={<ReceptionistConfig />} />
                  <Route path="/history" element={<CallHistory />} />
                  <Route path="/analytics" element={<Analytics />} />
                  <Route path="/settings" element={<Settings />} />
                </Routes>
              </div>
            </div>
          </main>
        </div>
      </div>
      <Toaster position="top-right" />
    </Router>
  );
}

export default App;
