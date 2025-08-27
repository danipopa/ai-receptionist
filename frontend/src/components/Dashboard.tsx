import React, { useState, useEffect } from 'react';
import { ChartBarIcon, PhoneIcon, UserGroupIcon, ClockIcon } from '@heroicons/react/24/outline';
import { apiService } from '../services/api';

interface DashboardStats {
  total_businesses: number;
  active_calls: number;
  calls_today: number;
  avg_call_duration: number;
}

function Dashboard() {
  const [stats, setStats] = useState<DashboardStats>({
    total_businesses: 0,
    active_calls: 0,
    calls_today: 0,
    avg_call_duration: 0
  });
  const [recentCalls, setRecentCalls] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    try {
      setLoading(true);
      
      // Load stats
      const [businessesData, activeCallsData, analyticsData] = await Promise.all([
        apiService.getBusinesses(),
        apiService.getActiveCalls(),
        apiService.getSystemAnalytics('24h')
      ]);

      setStats({
        total_businesses: businessesData.length,
        active_calls: activeCallsData.length,
        calls_today: analyticsData.calls_today || 0,
        avg_call_duration: analyticsData.avg_call_duration || 0
      });

      // Load recent calls
      const callsData = await apiService.getAllCalls(10);
      setRecentCalls(callsData);
      
    } catch (error) {
      console.error('Error loading dashboard data:', error);
    } finally {
      setLoading(false);
    }
  };

  const statItems = [
    {
      name: 'Total Businesses',
      value: stats.total_businesses,
      icon: UserGroupIcon,
      color: 'text-blue-600',
      bgColor: 'bg-blue-100'
    },
    {
      name: 'Active Calls',
      value: stats.active_calls,
      icon: PhoneIcon,
      color: 'text-green-600',
      bgColor: 'bg-green-100'
    },
    {
      name: 'Calls Today',
      value: stats.calls_today,
      icon: ChartBarIcon,
      color: 'text-purple-600',
      bgColor: 'bg-purple-100'
    },
    {
      name: 'Avg Call Duration',
      value: `${Math.round(stats.avg_call_duration)}s`,
      icon: ClockIcon,
      color: 'text-yellow-600',
      bgColor: 'bg-yellow-100'
    }
  ];

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
      </div>
    );
  }

  return (
    <div>
      <div className="mb-8">
        <h2 className="text-2xl font-bold text-gray-900">Dashboard Overview</h2>
        <p className="mt-2 text-sm text-gray-600">
          Monitor your AI receptionist platform performance
        </p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4 mb-8">
        {statItems.map((item) => (
          <div
            key={item.name}
            className="relative bg-white pt-5 px-4 pb-12 sm:pt-6 sm:px-6 shadow rounded-lg overflow-hidden"
          >
            <dt>
              <div className={`absolute ${item.bgColor} rounded-md p-3`}>
                <item.icon className={`h-6 w-6 ${item.color}`} aria-hidden="true" />
              </div>
              <p className="ml-16 text-sm font-medium text-gray-500 truncate">{item.name}</p>
            </dt>
            <dd className="ml-16 pb-6 flex items-baseline sm:pb-7">
              <p className="text-2xl font-semibold text-gray-900">{item.value}</p>
            </dd>
          </div>
        ))}
      </div>

      {/* Recent Activity */}
      <div className="bg-white shadow rounded-lg">
        <div className="px-4 py-5 sm:p-6">
          <h3 className="text-lg leading-6 font-medium text-gray-900 mb-4">
            Recent Call Activity
          </h3>
          
          {recentCalls.length === 0 ? (
            <div className="text-center py-8">
              <PhoneIcon className="mx-auto h-12 w-12 text-gray-400" />
              <h3 className="mt-2 text-sm font-medium text-gray-900">No recent calls</h3>
              <p className="mt-1 text-sm text-gray-500">
                Call activity will appear here once your AI receptionists start receiving calls.
              </p>
            </div>
          ) : (
            <div className="flow-root">
              <ul role="list" className="-mb-8">
                {recentCalls.map((call: any, callIdx) => (
                  <li key={call.id}>
                    <div className="relative pb-8">
                      {callIdx !== recentCalls.length - 1 ? (
                        <span
                          className="absolute top-4 left-4 -ml-px h-full w-0.5 bg-gray-200"
                          aria-hidden="true"
                        />
                      ) : null}
                      <div className="relative flex space-x-3">
                        <div>
                          <span className="h-8 w-8 rounded-full bg-green-500 flex items-center justify-center ring-8 ring-white">
                            <PhoneIcon className="h-5 w-5 text-white" aria-hidden="true" />
                          </span>
                        </div>
                        <div className="min-w-0 flex-1 pt-1.5 flex justify-between space-x-4">
                          <div>
                            <p className="text-sm text-gray-500">
                              Call from <span className="font-medium text-gray-900">{call.caller_id}</span>
                            </p>
                            <p className="text-sm text-gray-500">
                              Business: {call.business_name || 'Unknown'}
                            </p>
                          </div>
                          <div className="text-right text-sm whitespace-nowrap text-gray-500">
                            <time dateTime={call.start_time}>
                              {new Date(call.start_time).toLocaleTimeString()}
                            </time>
                          </div>
                        </div>
                      </div>
                    </div>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default Dashboard;
