import { useState, useEffect, useCallback } from 'react';
import { Trash2, RefreshCw, ArrowLeft, AlertCircle, User, Filter, Loader2, RotateCcw, Trash } from 'lucide-react';
import { Link } from 'react-router-dom';
import clsx from 'clsx';

import { useTenant } from '../context/TenantContext';
import { useGlobalSettings } from '../context/GlobalSettingsContext';
import { useAuthFetch, useAuth } from '../context/AuthContext';

interface TrashItem {
    id: string;
    name: string;
    size: string;
    size_bytes?: number;
    modified: string | null;
    deleted_at: string | null;
    original_path: string;
    owner_name?: string;
    owner_id?: string;
}

interface UserOption {
    id: string;
    name: string;
    email: string;
}

export default function RecycleBin() {
    const [items, setItems] = useState<TrashItem[]>([]);
    const [isLoading, setIsLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [selectedOwner, setSelectedOwner] = useState<string>('all');
    const [users, setUsers] = useState<UserOption[]>([]);
    const [isRestoring, setIsRestoring] = useState<string | null>(null);
    const [isDeleting, setIsDeleting] = useState<string | null>(null);
    
    const { currentCompany } = useTenant();
    const { formatDate } = useGlobalSettings();
    const authFetch = useAuthFetch();
    const { user } = useAuth();
    
    const companyId = currentCompany?.id;
    const isAdmin = user?.role === 'SuperAdmin' || user?.role === 'Admin';

    // Fetch users for filter dropdown (admins only)
    useEffect(() => {
        if (!companyId || !isAdmin) return;
        
        const fetchUsers = async () => {
            try {
                const response = await authFetch(`/api/users/${companyId}`);
                if (response.ok) {
                    const data = await response.json();
                    setUsers(data.map((u: any) => ({
                        id: u.id,
                        name: u.name,
                        email: u.email,
                    })));
                }
            } catch (err) {
                console.error('Failed to fetch users for filter', err);
            }
        };
        fetchUsers();
    }, [companyId, isAdmin, authFetch]);

    const fetchTrash = useCallback(async () => {
        if (!companyId) return;
        
        setIsLoading(true);
        setError(null);
        
        try {
            // Build URL with owner filter for admins
            let url = `/api/trash/${companyId}`;
            if (isAdmin && selectedOwner !== 'all') {
                url += `?owner_id=${selectedOwner}`;
            }
            
            const response = await authFetch(url);
            
            if (!response.ok) {
                if (response.status === 401) {
                    throw new Error('Session expired. Please log in again.');
                } else if (response.status === 403) {
                    throw new Error('You do not have permission to view the recycle bin.');
                } else {
                    throw new Error(`Failed to fetch recycle bin (${response.status})`);
                }
            }
            
            const data = await response.json();
            setItems(data || []);
        } catch (err) {
            console.error('Failed to fetch trash', err);
            setError(err instanceof Error ? err.message : 'Failed to load recycle bin');
        } finally {
            setIsLoading(false);
        }
    }, [companyId, authFetch, isAdmin, selectedOwner]);

    useEffect(() => {
        if (companyId) {
            fetchTrash();
        }
    }, [companyId, fetchTrash]);

    const handleRestore = async (item: TrashItem) => {
        if (!companyId) return;
        
        setIsRestoring(item.id);
        try {
            const response = await authFetch(`/api/trash/${companyId}/restore/${encodeURIComponent(item.name)}`, {
                method: 'POST'
            });
            
            if (!response.ok) {
                throw new Error('Failed to restore file');
            }
            
            // Remove from local state immediately for snappy UI
            setItems(prev => prev.filter(i => i.id !== item.id));
        } catch (err) {
            console.error('Failed to restore file', err);
            setError('Failed to restore file. Please try again.');
        } finally {
            setIsRestoring(null);
        }
    };

    const handleDelete = async (item: TrashItem) => {
        if (!companyId) return;
        if (!confirm(`Permanently delete "${item.name}"? This cannot be undone.`)) return;
        
        setIsDeleting(item.id);
        try {
            const response = await authFetch(`/api/trash/${companyId}/delete/${encodeURIComponent(item.name)}`, {
                method: 'POST'
            });
            
            if (!response.ok) {
                throw new Error('Failed to delete file');
            }
            
            // Remove from local state immediately
            setItems(prev => prev.filter(i => i.id !== item.id));
        } catch (err) {
            console.error('Failed to delete file', err);
            setError('Failed to permanently delete file. Please try again.');
        } finally {
            setIsDeleting(null);
        }
    };

    const formatFileSize = (bytes?: number): string => {
        if (!bytes) return 'Unknown size';
        if (bytes < 1024) return `${bytes} B`;
        if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
        if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
        return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
    };

    const safeFormatDate = (dateStr: string | null | undefined): string => {
        if (!dateStr) return 'Unknown date';
        try {
            return formatDate(dateStr);
        } catch {
            return 'Invalid date';
        }
    };

    return (
        <div className="h-full flex flex-col space-y-4">
            {/* Header */}
            <div className="flex items-center justify-between mb-4">
                <div className="flex items-center space-x-4">
                    <Link 
                        to="/files" 
                        className="p-2 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-800 text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white transition-colors"
                    >
                        <ArrowLeft className="w-5 h-5" />
                    </Link>
                    <div>
                        <h1 className="text-2xl font-bold text-gray-900 dark:text-white flex items-center">
                            <Trash2 className="w-6 h-6 mr-3 text-red-500 dark:text-red-400" />
                            Recycle Bin
                        </h1>
                        <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">
                            Items in the recycle bin will be permanently deleted after {currentCompany?.retention_policy_days || 30} days.
                        </p>
                    </div>
                </div>
                
                <div className="flex items-center space-x-3">
                    {/* User filter for admins */}
                    {isAdmin && users.length > 0 && (
                        <div className="flex items-center space-x-2">
                            <Filter className="w-4 h-4 text-gray-400" />
                            <select
                                value={selectedOwner}
                                onChange={(e) => setSelectedOwner(e.target.value)}
                                className="text-sm border border-gray-300 dark:border-gray-600 rounded-lg px-3 py-2 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
                            >
                                <option value="all">All Users</option>
                                {users.map(u => (
                                    <option key={u.id} value={u.id}>{u.name}</option>
                                ))}
                            </select>
                        </div>
                    )}
                    
                    <button
                        onClick={fetchTrash}
                        disabled={isLoading}
                        className="p-3 text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white hover:bg-gray-200 dark:hover:bg-gray-700 rounded-lg transition-all disabled:opacity-50"
                        title="Refresh"
                    >
                        <RefreshCw className={clsx("w-5 h-5", isLoading && "animate-spin")} />
                    </button>
                </div>
            </div>

            {/* Error Alert */}
            {error && (
                <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-xl p-4 flex items-start space-x-3">
                    <AlertCircle className="w-5 h-5 text-red-500 flex-shrink-0 mt-0.5" />
                    <div className="flex-1">
                        <p className="text-sm text-red-700 dark:text-red-300">{error}</p>
                    </div>
                    <button
                        onClick={() => setError(null)}
                        className="text-red-500 hover:text-red-700 dark:hover:text-red-300"
                    >
                        ×
                    </button>
                </div>
            )}

            {/* Content */}
            {isLoading ? (
                <div className="text-center py-20">
                    <Loader2 className="w-12 h-12 text-primary-500 mx-auto animate-spin" />
                    <p className="mt-4 text-gray-500 dark:text-gray-400">Loading recycle bin...</p>
                </div>
            ) : items.length === 0 ? (
                <div className="text-center py-20 bg-white dark:bg-gray-800 rounded-2xl border border-gray-200 dark:border-gray-700 shadow-sm">
                    <Trash2 className="w-16 h-16 text-gray-300 dark:text-gray-600 mx-auto mb-4" />
                    <p className="text-gray-500 dark:text-gray-400 text-lg">
                        {selectedOwner !== 'all' ? 'No deleted files for this user' : 'Recycle bin is empty'}
                    </p>
                    {selectedOwner !== 'all' && (
                        <button
                            onClick={() => setSelectedOwner('all')}
                            className="mt-4 text-primary-600 hover:text-primary-700 dark:text-primary-400 text-sm font-medium"
                        >
                            Show all users' files
                        </button>
                    )}
                </div>
            ) : (
                <div className="bg-white dark:bg-gray-800 shadow-sm overflow-hidden rounded-2xl border border-gray-200 dark:border-gray-700">
                    {/* Table Header for Admins */}
                    {isAdmin && (
                        <div className="px-6 py-3 bg-gray-50 dark:bg-gray-700/50 border-b border-gray-200 dark:border-gray-700 grid grid-cols-12 gap-4 text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                            <div className="col-span-5">File</div>
                            <div className="col-span-2">Owner</div>
                            <div className="col-span-2">Deleted</div>
                            <div className="col-span-3 text-right">Actions</div>
                        </div>
                    )}
                    
                    <div className="divide-y divide-gray-200 dark:divide-gray-700">
                        {items.map((item) => (
                            <div 
                                key={item.id} 
                                className={clsx(
                                    "px-6 py-5 hover:bg-gray-50 dark:hover:bg-gray-700/50 transition-colors group",
                                    isAdmin ? "grid grid-cols-12 gap-4 items-center" : "flex items-center justify-between"
                                )}
                            >
                                {/* File Info */}
                                <div className={clsx("flex items-center min-w-0", isAdmin ? "col-span-5" : "flex-1")}>
                                    <div className="flex-shrink-0 h-12 w-12 rounded-xl bg-red-100 dark:bg-red-500/20 flex items-center justify-center group-hover:bg-red-200 dark:group-hover:bg-red-500/30 transition-colors">
                                        <Trash2 className="h-6 w-6 text-red-600 dark:text-red-400" />
                                    </div>
                                    <div className="ml-4 min-w-0">
                                        <div className="text-sm font-medium text-gray-900 dark:text-white truncate" title={item.name}>
                                            {item.name}
                                        </div>
                                        <div className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                                            {item.size || formatFileSize(item.size_bytes)}
                                            {item.original_path && (
                                                <span className="ml-2 text-gray-400 dark:text-gray-500">
                                                    from {item.original_path}
                                                </span>
                                            )}
                                        </div>
                                    </div>
                                </div>
                                
                                {/* Owner (Admin only) */}
                                {isAdmin && (
                                    <div className="col-span-2 flex items-center text-sm text-gray-600 dark:text-gray-400">
                                        <User className="w-4 h-4 mr-2 text-gray-400" />
                                        <span className="truncate">{item.owner_name || 'Unknown'}</span>
                                    </div>
                                )}
                                
                                {/* Deleted Date */}
                                {isAdmin ? (
                                    <div className="col-span-2 text-sm text-gray-500 dark:text-gray-400">
                                        {safeFormatDate(item.deleted_at || item.modified)}
                                    </div>
                                ) : (
                                    <div className="text-xs text-gray-500 dark:text-gray-400 mx-4">
                                        Deleted {safeFormatDate(item.deleted_at || item.modified)}
                                    </div>
                                )}
                                
                                {/* Actions */}
                                <div className={clsx("flex space-x-2", isAdmin ? "col-span-3 justify-end" : "")}>
                                    <button
                                        onClick={() => handleRestore(item)}
                                        disabled={isRestoring === item.id}
                                        className="px-4 py-2 text-sm font-medium rounded-lg text-emerald-700 dark:text-emerald-400 bg-emerald-100 dark:bg-emerald-500/20 hover:bg-emerald-200 dark:hover:bg-emerald-500/30 border border-emerald-200 dark:border-emerald-500/30 transition-all disabled:opacity-50 flex items-center gap-1"
                                    >
                                        {isRestoring === item.id ? (
                                            <Loader2 className="w-4 h-4 animate-spin" />
                                        ) : (
                                            <RotateCcw className="w-4 h-4" />
                                        )}
                                        Restore
                                    </button>
                                    <button
                                        onClick={() => handleDelete(item)}
                                        disabled={isDeleting === item.id}
                                        className="px-4 py-2 text-sm font-medium rounded-lg text-red-700 dark:text-red-400 bg-red-100 dark:bg-red-500/20 hover:bg-red-200 dark:hover:bg-red-500/30 border border-red-200 dark:border-red-500/30 transition-all disabled:opacity-50 flex items-center gap-1"
                                    >
                                        {isDeleting === item.id ? (
                                            <Loader2 className="w-4 h-4 animate-spin" />
                                        ) : (
                                            <Trash className="w-4 h-4" />
                                        )}
                                        Delete
                                    </button>
                                </div>
                            </div>
                        ))}
                    </div>
                </div>
            )}
            
            {/* Item count */}
            {!isLoading && items.length > 0 && (
                <p className="text-sm text-gray-500 dark:text-gray-400 text-center">
                    {items.length} {items.length === 1 ? 'item' : 'items'} in recycle bin
                </p>
            )}
        </div>
    );
}
