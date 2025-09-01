import React, { useState, useEffect } from 'react';
import { PlusIcon, PencilIcon, TrashIcon, XMarkIcon } from '@heroicons/react/24/outline';
import { apiService } from '../services/api';
import toast from 'react-hot-toast';

interface Business {
  id: number;
  name: string;
  phone: string;
  industry: string;
  status: string;
  created_at: string;
  welcome_message?: string;
}

function BusinessList() {
  const [businesses, setBusinesses] = useState<Business[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [editingBusiness, setEditingBusiness] = useState<Business | null>(null);
  const [newBusiness, setNewBusiness] = useState({
    name: '',
    phone_number: '',
    welcome_message: '',
    industry: ''
  });
  const [editBusiness, setEditBusiness] = useState({
    name: '',
    phone_number: '',
    welcome_message: '',
    industry: ''
  });
  const [creating, setCreating] = useState(false);
  const [updating, setUpdating] = useState(false);

  useEffect(() => {
    loadBusinesses();
  }, []);

  const loadBusinesses = async () => {
    try {
      const data = await apiService.getBusinesses();
      setBusinesses(data);
    } catch (error) {
      console.error('Error loading businesses:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleCreateBusiness = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newBusiness.name.trim()) {
      toast.error('Business name is required');
      return;
    }

    setCreating(true);
    try {
      const createdBusiness = await apiService.createBusiness(newBusiness);
      setBusinesses([...businesses, createdBusiness]);
      setShowCreateModal(false);
      setNewBusiness({ name: '', phone_number: '', welcome_message: '', industry: '' });
      toast.success('Business created successfully');
    } catch (error) {
      console.error('Error creating business:', error);
      toast.error('Failed to create business');
    } finally {
      setCreating(false);
    }
  };

  const resetModal = () => {
    setShowCreateModal(false);
    setNewBusiness({ name: '', phone_number: '', welcome_message: '', industry: '' });
  };

  const handleEditBusiness = (business: Business) => {
    setEditingBusiness(business);
    setEditBusiness({
      name: business.name,
      phone_number: business.phone || '',
      welcome_message: business.welcome_message || '',
      industry: business.industry || ''
    });
    setShowEditModal(true);
  };

  const handleUpdateBusiness = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editBusiness.name.trim() || !editingBusiness) {
      toast.error('Business name is required');
      return;
    }

    setUpdating(true);
    try {
      const updatedBusiness = await apiService.updateBusiness(editingBusiness.id.toString(), editBusiness);
      setBusinesses(businesses.map(b => 
        b.id === editingBusiness.id ? updatedBusiness : b
      ));
      setShowEditModal(false);
      setEditingBusiness(null);
      setEditBusiness({ name: '', phone_number: '', welcome_message: '', industry: '' });
      toast.success('Business updated successfully');
    } catch (error) {
      console.error('Error updating business:', error);
      toast.error('Failed to update business');
    } finally {
      setUpdating(false);
    }
  };

  const resetEditModal = () => {
    setShowEditModal(false);
    setEditingBusiness(null);
    setEditBusiness({ name: '', phone_number: '', welcome_message: '', industry: '' });
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
      <div className="mb-8 flex justify-between items-center">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Businesses</h2>
          <p className="mt-2 text-sm text-gray-600">
            Manage your AI receptionist clients
          </p>
        </div>
        <button
          onClick={() => setShowCreateModal(true)}
          className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
        >
          <PlusIcon className="h-5 w-5 mr-2" />
          Add Business
        </button>
      </div>

      <div className="bg-white shadow overflow-hidden sm:rounded-md">
        <ul role="list" className="divide-y divide-gray-200">
          {businesses.map((business) => (
            <li key={business.id}>
              <div className="px-4 py-4 flex items-center justify-between">
                <div className="flex items-center">
                  <div className="flex-shrink-0">
                    <div className="h-10 w-10 rounded-full bg-gray-300 flex items-center justify-center">
                      <span className="text-sm font-medium text-gray-700">
                        {business.name.charAt(0).toUpperCase()}
                      </span>
                    </div>
                  </div>
                  <div className="ml-4">
                    <div className="flex items-center">
                      <p className="text-sm font-medium text-gray-900">
                        {business.name}
                      </p>
                      <span className={`ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                        business.status === 'active' 
                          ? 'bg-green-100 text-green-800' 
                          : 'bg-red-100 text-red-800'
                      }`}>
                        {business.status === 'active' ? 'Active' : 'Inactive'}
                      </span>
                    </div>
                    <div className="flex items-center text-sm text-gray-500">
                      <p>{business.phone || 'No phone number'}</p>
                      <span className="mx-2">•</span>
                      <p>Created {new Date(business.created_at).toLocaleDateString()}</p>
                    </div>
                  </div>
                </div>
                
                <div className="flex items-center space-x-2">
                  <button 
                    onClick={() => handleEditBusiness(business)}
                    className="inline-flex items-center p-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
                  >
                    <PencilIcon className="h-4 w-4" />
                  </button>
                  <button className="inline-flex items-center p-2 border border-gray-300 rounded-md text-sm font-medium text-red-700 bg-white hover:bg-red-50">
                    <TrashIcon className="h-4 w-4" />
                  </button>
                </div>
              </div>
            </li>
          ))}
        </ul>
      </div>

      {/* Create Business Modal */}
      {showCreateModal && (
        <div className="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
          <div className="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
            <div className="mt-3">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-medium text-gray-900">Add New Business</h3>
                <button
                  onClick={resetModal}
                  className="text-gray-400 hover:text-gray-600"
                >
                  <XMarkIcon className="h-6 w-6" />
                </button>
              </div>
              
              <form onSubmit={handleCreateBusiness} className="space-y-4">
                <div>
                  <label htmlFor="business-name" className="block text-sm font-medium text-gray-700">
                    Business Name *
                  </label>
                  <input
                    type="text"
                    id="business-name"
                    value={newBusiness.name}
                    onChange={(e) => setNewBusiness({ ...newBusiness, name: e.target.value })}
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-indigo-500 focus:border-indigo-500"
                    placeholder="Enter business name"
                    required
                  />
                </div>

                <div>
                  <label htmlFor="phone-number" className="block text-sm font-medium text-gray-700">
                    Phone Number
                  </label>
                  <input
                    type="tel"
                    id="phone-number"
                    value={newBusiness.phone_number}
                    onChange={(e) => setNewBusiness({ ...newBusiness, phone_number: e.target.value })}
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-indigo-500 focus:border-indigo-500"
                    placeholder="+1-555-0123"
                  />
                </div>

                <div>
                  <label htmlFor="industry" className="block text-sm font-medium text-gray-700">
                    Industry
                  </label>
                  <select
                    id="industry"
                    value={newBusiness.industry}
                    onChange={(e) => setNewBusiness({ ...newBusiness, industry: e.target.value })}
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-indigo-500 focus:border-indigo-500"
                  >
                    <option value="">Select industry</option>
                    <option value="Technology">Technology</option>
                    <option value="Healthcare">Healthcare</option>
                    <option value="Legal">Legal</option>
                    <option value="Retail">Retail</option>
                    <option value="Restaurant">Restaurant</option>
                    <option value="Real Estate">Real Estate</option>
                    <option value="Financial Services">Financial Services</option>
                    <option value="Other">Other</option>
                  </select>
                </div>

                <div>
                  <label htmlFor="welcome-message" className="block text-sm font-medium text-gray-700">
                    Welcome Message
                  </label>
                  <textarea
                    id="welcome-message"
                    rows={3}
                    value={newBusiness.welcome_message}
                    onChange={(e) => setNewBusiness({ ...newBusiness, welcome_message: e.target.value })}
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-indigo-500 focus:border-indigo-500"
                    placeholder="Thank you for calling! How can I assist you today?"
                  />
                </div>

                <div className="flex justify-end space-x-3 pt-4">
                  <button
                    type="button"
                    onClick={resetModal}
                    className="px-4 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={creating}
                    className="px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {creating ? 'Creating...' : 'Create Business'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}

      {/* Edit Business Modal */}
      {showEditModal && editingBusiness && (
        <div className="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
          <div className="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
            <div className="mt-3">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-medium text-gray-900">Edit Business</h3>
                <button
                  onClick={resetEditModal}
                  className="text-gray-400 hover:text-gray-600"
                >
                  <XMarkIcon className="h-6 w-6" />
                </button>
              </div>
              
              <form onSubmit={handleUpdateBusiness} className="space-y-4">
                <div>
                  <label htmlFor="edit-business-name" className="block text-sm font-medium text-gray-700">
                    Business Name *
                  </label>
                  <input
                    type="text"
                    id="edit-business-name"
                    value={editBusiness.name}
                    onChange={(e) => setEditBusiness({ ...editBusiness, name: e.target.value })}
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-indigo-500 focus:border-indigo-500"
                    placeholder="Enter business name"
                    required
                  />
                </div>

                <div>
                  <label htmlFor="edit-phone-number" className="block text-sm font-medium text-gray-700">
                    Phone Number
                  </label>
                  <input
                    type="tel"
                    id="edit-phone-number"
                    value={editBusiness.phone_number}
                    onChange={(e) => setEditBusiness({ ...editBusiness, phone_number: e.target.value })}
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-indigo-500 focus:border-indigo-500"
                    placeholder="+1-555-0123"
                  />
                </div>

                <div>
                  <label htmlFor="edit-industry" className="block text-sm font-medium text-gray-700">
                    Industry
                  </label>
                  <select
                    id="edit-industry"
                    value={editBusiness.industry}
                    onChange={(e) => setEditBusiness({ ...editBusiness, industry: e.target.value })}
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-indigo-500 focus:border-indigo-500"
                  >
                    <option value="">Select industry</option>
                    <option value="Technology">Technology</option>
                    <option value="Healthcare">Healthcare</option>
                    <option value="Legal">Legal</option>
                    <option value="Retail">Retail</option>
                    <option value="Restaurant">Restaurant</option>
                    <option value="Real Estate">Real Estate</option>
                    <option value="Financial Services">Financial Services</option>
                    <option value="Other">Other</option>
                  </select>
                </div>

                <div>
                  <label htmlFor="edit-welcome-message" className="block text-sm font-medium text-gray-700">
                    Welcome Message
                  </label>
                  <textarea
                    id="edit-welcome-message"
                    rows={3}
                    value={editBusiness.welcome_message}
                    onChange={(e) => setEditBusiness({ ...editBusiness, welcome_message: e.target.value })}
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-indigo-500 focus:border-indigo-500"
                    placeholder="Thank you for calling! How can I assist you today?"
                  />
                </div>

                <div className="flex justify-end space-x-3 pt-4">
                  <button
                    type="button"
                    onClick={resetEditModal}
                    className="px-4 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={updating}
                    className="px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {updating ? 'Updating...' : 'Update Business'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default BusinessList;
