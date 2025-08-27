import React, { useState, useEffect } from 'react';
import { PhoneIcon, PlayIcon, StopIcon } from '@heroicons/react/24/outline';
import { apiService } from '../services/api';

interface ActiveCall {
  id: string;
  caller_id: string;
  business_name: string;
  duration: number;
  status: string;
  start_time: string;
}

function LiveCalls() {
  const [activeCalls, setActiveCalls] = useState<ActiveCall[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadActiveCalls();
    
    // Refresh every 5 seconds
    const interval = setInterval(loadActiveCalls, 5000);
    
    return () => clearInterval(interval);
  }, []);

  const loadActiveCalls = async () => {
    try {
      const calls = await apiService.getActiveCalls();
      setActiveCalls(calls);
    } catch (error) {
      console.error('Error loading active calls:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleEndCall = async (callId: string) => {
    try {
      await apiService.endCall(callId);
      await loadActiveCalls(); // Refresh the list
    } catch (error) {
      console.error('Error ending call:', error);
    }
  };

  const formatDuration = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

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
        <h2 className="text-2xl font-bold text-gray-900">Live Calls</h2>
        <p className="mt-2 text-sm text-gray-600">
          Monitor and manage active calls in real-time
        </p>
      </div>

      {activeCalls.length === 0 ? (
        <div className="text-center py-12">
          <PhoneIcon className="mx-auto h-12 w-12 text-gray-400" />
          <h3 className="mt-2 text-sm font-medium text-gray-900">No active calls</h3>
          <p className="mt-1 text-sm text-gray-500">
            Active calls will appear here when your AI receptionists receive calls.
          </p>
        </div>
      ) : (
        <div className="bg-white shadow overflow-hidden sm:rounded-md">
          <ul role="list" className="divide-y divide-gray-200">
            {activeCalls.map((call) => (
              <li key={call.id}>
                <div className="px-4 py-4 flex items-center justify-between">
                  <div className="flex items-center">
                    <div className="flex-shrink-0">
                      <div className="h-10 w-10 rounded-full bg-green-100 flex items-center justify-center">
                        <PhoneIcon className="h-6 w-6 text-green-600" />
                      </div>
                    </div>
                    <div className="ml-4">
                      <div className="flex items-center">
                        <p className="text-sm font-medium text-gray-900">
                          {call.caller_id}
                        </p>
                        <span className="ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                          Live
                        </span>
                      </div>
                      <div className="flex items-center text-sm text-gray-500">
                        <p>{call.business_name}</p>
                        <span className="mx-2">•</span>
                        <p>{formatDuration(call.duration)}</p>
                      </div>
                    </div>
                  </div>
                  
                  <div className="flex items-center space-x-2">
                    <button
                      onClick={() => handleEndCall(call.id)}
                      className="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
                    >
                      <StopIcon className="h-4 w-4 mr-2" />
                      End Call
                    </button>
                  </div>
                </div>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}

export default LiveCalls;
