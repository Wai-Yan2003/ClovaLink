import React, { useState, useEffect, useRef, useMemo, useCallback } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import {
    Folder, FileText, Image as ImageIcon, MoreVertical, Download,
    Trash2, Eye, EyeOff, Upload, Grid, List, Search, Plus, Star, Clock,
    FolderPlus, Edit2, Link as LinkIcon, ChevronLeft, ChevronRight, ChevronDown,
    Lock, Unlock, History, FileOutput, Move, Home, Users, CheckSquare, Square, X,
    Building2, MoreHorizontal
} from 'lucide-react';
import clsx from 'clsx';
import { CreateFileRequestModal, FileRequestData } from '../components/CreateFileRequestModal';
import { UploadProgressModal, UploadFile } from '../components/UploadProgressModal';
import { FilePreviewModal } from '../components/FilePreviewModal';
import { RenameModal } from '../components/RenameModal';
import { NewFolderModal } from '../components/NewFolderModal';
import { FileActivityModal } from '../components/FileActivityModal';
import { LockFileModal, UnlockFileModal } from '../components/LockFileModal';
import { MoveFileModal } from '../components/MoveFileModal';
import { FileActionMenu } from '../components/FileActionMenu';
import { FilePropertiesModal } from '../components/FilePropertiesModal';
import { ShareFileModal } from '../components/ShareFileModal';
import { Avatar } from '../components/Avatar';
import { useTenant } from '../context/TenantContext';
import { useAuth, useAuthFetch } from '../context/AuthContext';
import { useKeyboardShortcuts, Shortcut } from '../hooks/useKeyboardShortcuts';
import { useKeyboardShortcutsContext } from '../context/KeyboardShortcutsContext';
import { ShortcutActionId } from '../hooks/shortcutPresets';

interface FileItem {
    id: string;
    name: string;
    type: 'folder' | 'image' | 'document' | 'video' | 'audio';
    size?: string;
    size_bytes?: number;
    modified: string;
    created_at?: string;
    owner: string;
    owner_id?: string;
    owner_avatar?: string;
    is_starred?: boolean;
    is_locked?: boolean;
    locked_by?: string;
    locked_at?: string;
    lock_requires_role?: string;
    has_lock_password?: boolean;
    visibility?: 'department' | 'private';
    department_id?: string;
    content_type?: string;
    storage_path?: string;
    is_company_folder?: boolean;
}

interface UserPrefs {
    starred: string[];
    settings: any;
}

export function FileBrowser() {
    const [viewMode, setViewMode] = useState<'grid' | 'list'>('grid');
    const [currentPath, setCurrentPath] = useState<string[]>(['Home']);
    const [files, setFiles] = useState<FileItem[]>([]);
    const [starredFiles, setStarredFiles] = useState<string[]>([]);
    const [isLoading, setIsLoading] = useState(true);
    const [activeMenu, setActiveMenu] = useState<string | null>(null);
    const [showMoreStarred, setShowMoreStarred] = useState(false);
    const [previewFile, setPreviewFile] = useState<{ name: string, url: string, type: any } | null>(null);
    const [isRequestModalOpen, setIsRequestModalOpen] = useState(false);
    const [isUploadModalOpen, setIsUploadModalOpen] = useState(false);
    const [uploadFilesList, setUploadFilesList] = useState<UploadFile[]>([]);
    const [isDragging, setIsDragging] = useState(false);
    
    // File view mode: 'department' or 'private'
    const [fileViewMode, setFileViewMode] = useState<'department' | 'private'>('department');
    const [isViewModeOpen, setIsViewModeOpen] = useState(false);
    const viewModeRef = useRef<HTMLDivElement>(null);
    
    // Mobile overflow menu
    const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
    const mobileMenuRef = useRef<HTMLDivElement>(null);
    
    // Department filtering for admins
    const [departments, setDepartments] = useState<{id: string, name: string}[]>([]);
    const [selectedDepartment, setSelectedDepartment] = useState<string | null>(null);

    // Modals
    const [isRenameOpen, setIsRenameOpen] = useState(false);
    const [fileToRename, setFileToRename] = useState<FileItem | null>(null);
    const [isNewFolderOpen, setIsNewFolderOpen] = useState(false);
    const [isActivityModalOpen, setIsActivityModalOpen] = useState(false);
    const [activityFile, setActivityFile] = useState<FileItem | null>(null);
    
    // Lock modals
    const [isLockModalOpen, setIsLockModalOpen] = useState(false);
    const [isUnlockModalOpen, setIsUnlockModalOpen] = useState(false);
    const [lockingFile, setLockingFile] = useState<FileItem | null>(null);
    const [isLocking, setIsLocking] = useState(false);
    
    // Move modal
    const [isMoveModalOpen, setIsMoveModalOpen] = useState(false);
    const [movingFile, setMovingFile] = useState<FileItem | null>(null);
    const [isMoving, setIsMoving] = useState(false);
    
    // Properties modal
    const [isPropertiesModalOpen, setIsPropertiesModalOpen] = useState(false);
    const [propertiesFile, setPropertiesFile] = useState<FileItem | null>(null);
    
    // Share modal
    const [isShareModalOpen, setIsShareModalOpen] = useState(false);
    const [shareFile, setShareFile] = useState<FileItem | null>(null);
    
    // Drop target state for move
    const [dropTargetId, setDropTargetId] = useState<string | null>(null);
    
    // Bulk selection state
    const [selectedFiles, setSelectedFiles] = useState<Set<string>>(new Set());
    const [isSelectionMode, setIsSelectionMode] = useState(false);
    const [isBulkMoveModalOpen, setIsBulkMoveModalOpen] = useState(false);
    const [isBulkMoving, setIsBulkMoving] = useState(false);

    // Keyboard navigation state
    const [focusedFileIndex, setFocusedFileIndex] = useState<number>(-1);

    // Dynamic items per page based on screen width
    const [itemsPerPage, setItemsPerPage] = useState(24);

    const fileInputRef = useRef<HTMLInputElement>(null);
    const starredDropdownRef = useRef<HTMLDivElement>(null);
    const menuButtonRefs = useRef<Map<string, HTMLButtonElement>>(new Map());
    const { currentCompany } = useTenant();
    const { user } = useAuth();
    const companyId = currentCompany?.id;
    const [searchParams] = useSearchParams();
    const urlPath = searchParams.get('path');

    // Initialize path from URL query parameter (for search result navigation)
    useEffect(() => {
        if (urlPath) {
            // Convert "Work Projects/subfolder" to ["Home", "Work Projects", "subfolder"]
            const pathParts = urlPath.split('/').filter(p => p);
            setCurrentPath(['Home', ...pathParts]);
        }
    }, [urlPath]);

    // Calculate items per page based on screen width for responsive pagination
    useEffect(() => {
        const calculateItemsPerPage = () => {
            const width = window.innerWidth;
            if (width >= 3200) return 64;      // 16 cols x 4 rows
            if (width >= 2800) return 56;      // 14 cols x 4 rows
            if (width >= 2200) return 48;      // 12 cols x 4 rows
            if (width >= 1800) return 40;      // 10 cols x 4 rows
            if (width >= 1536) return 32;      // 8 cols x 4 rows (2xl)
            if (width >= 1280) return 24;      // 6 cols x 4 rows (xl)
            return 24;                          // default
        };
        
        setItemsPerPage(calculateItemsPerPage());
        
        const handleResize = () => setItemsPerPage(calculateItemsPerPage());
        window.addEventListener('resize', handleResize);
        return () => window.removeEventListener('resize', handleResize);
    }, []);

    // Fetch departments for filtering (admins only)
    useEffect(() => {
        if (companyId && (user?.role === 'Admin' || user?.role === 'SuperAdmin')) {
            authFetch('/api/departments')
                .then(res => res.ok ? res.json() : [])
                .then(data => setDepartments(data))
                .catch(() => setDepartments([]));
        }
    }, [companyId, user?.role]);

    // Fetch files on mount, path change, view mode change, or department filter change
    useEffect(() => {
        if (companyId) {
            fetchFiles();
        }
        // Clear selection when path or view mode changes
        setSelectedFiles(new Set());
        setIsSelectionMode(false);
    }, [companyId, currentPath, fileViewMode, selectedDepartment]);

    // Close menus when clicking outside
    useEffect(() => {
        const handleClickOutside = (event: MouseEvent) => {
            setActiveMenu(null);
            if (viewModeRef.current && !viewModeRef.current.contains(event.target as Node)) {
                setIsViewModeOpen(false);
            }
            if (starredDropdownRef.current && !starredDropdownRef.current.contains(event.target as Node)) {
                setShowMoreStarred(false);
            }
            if (mobileMenuRef.current && !mobileMenuRef.current.contains(event.target as Node)) {
                setIsMobileMenuOpen(false);
            }
        };
        document.addEventListener('click', handleClickOutside);
        return () => document.removeEventListener('click', handleClickOutside);
    }, []);

    const authFetch = useAuthFetch();

    // Selection helpers
    const toggleFileSelection = (fileId: string) => {
        setSelectedFiles(prev => {
            const newSet = new Set(prev);
            if (newSet.has(fileId)) {
                newSet.delete(fileId);
            } else {
                newSet.add(fileId);
            }
            return newSet;
        });
    };

    const selectAllFiles = () => {
        setSelectedFiles(new Set(files.map(f => f.id)));
    };

    const clearSelection = () => {
        setSelectedFiles(new Set());
        setIsSelectionMode(false);
    };

    // Bulk move handler
    const handleBulkMove = async (targetParentId: string | null, targetDepartmentId: string | null, targetVisibility: string = 'department') => {
        if (selectedFiles.size === 0 || !companyId) return;
        
        // Get only files user has permission to move
        const filesToMove = getSelectedFilesForAction('move');
        
        if (filesToMove.length === 0) {
            alert('Cannot move any of the selected files. Locked files cannot be moved.');
            setIsBulkMoveModalOpen(false);
            return;
        }
        
        setIsBulkMoving(true);
        
        try {
            let successCount = 0;
            let errorCount = 0;
            
            for (const file of filesToMove) {
                try {
                    const response = await authFetch(`/api/files/${companyId}/${file.id}/move`, {
                        method: 'PUT',
                        body: JSON.stringify({
                            target_parent_id: targetParentId,
                            target_department_id: targetDepartmentId,
                            target_visibility: targetVisibility
                        })
                    });
                    
                    const result = await response.json();
                    if (response.ok && !result.error) {
                        successCount++;
                    } else {
                        errorCount++;
                    }
                } catch {
                    errorCount++;
                }
            }
            
            const skippedCount = selectedFiles.size - filesToMove.length;
            if (errorCount > 0 || skippedCount > 0) {
                let message = `Moved ${successCount} file(s).`;
                if (errorCount > 0) message += ` ${errorCount} failed.`;
                if (skippedCount > 0) message += ` ${skippedCount} skipped (locked).`;
                alert(message);
            }
            
            fetchFiles();
            clearSelection();
            setIsBulkMoveModalOpen(false);
        } finally {
            setIsBulkMoving(false);
        }
    };

    // Bulk delete handler
    const handleBulkDelete = async () => {
        if (selectedFiles.size === 0 || !companyId) return;
        
        // Get only files user has permission to delete
        const filesToDelete = getSelectedFilesForAction('delete');
        
        if (filesToDelete.length === 0) {
            alert('You do not have permission to delete any of the selected files. Only file owners, Admins, and SuperAdmins can delete files.');
            return;
        }
        
        const skippedCount = selectedFiles.size - filesToDelete.length;
        let confirmMessage = `Are you sure you want to move ${filesToDelete.length} item(s) to the Recycle Bin?`;
        if (skippedCount > 0) {
            confirmMessage += `\n\n${skippedCount} item(s) will be skipped (locked or no permission).`;
        }
        
        if (!confirm(confirmMessage)) {
            return;
        }
        
        let successCount = 0;
        
        for (const file of filesToDelete) {
            const currentPathStr = currentPath.slice(1).join('/');
            const fullPath = currentPathStr ? `${currentPathStr}/${file.name}` : file.name;
            
            try {
                const response = await authFetch(`/api/files/${companyId}/delete`, {
                    method: 'POST',
                    body: JSON.stringify({ path: fullPath })
                });
                
                if (response.ok) {
                    successCount++;
                }
            } catch {
                // Continue with other files
            }
        }
        
        fetchFiles();
        clearSelection();
    };

    const fetchFiles = async () => {
        if (!companyId) {
            console.warn('fetchFiles called without companyId');
            return;
        }
        try {
            // Construct path from currentPath array (skip "Home")
            const path = currentPath.slice(1).join('/');

            // Fetch files with path, visibility, and optional department filter
            const deptParam = selectedDepartment ? `&department_id=${selectedDepartment}` : '';
            const filesRes = await authFetch(`/api/files/${companyId}?path=${encodeURIComponent(path)}&visibility=${fileViewMode}${deptParam}`);
            if (filesRes.ok) {
                const filesData = await filesRes.json();

                // Fetch prefs (starred)
                const prefsRes = await authFetch(`/api/prefs/${companyId}`);
                let prefsData: { starred: string[] } = { starred: [] };
                if (prefsRes.ok) {
                    prefsData = await prefsRes.json();
                }
                setStarredFiles(prefsData.starred || []);

                // Merge starred status and map types
                const mergedFiles = filesData.map((f: any) => {
                    const extension = f.name.split('.').pop()?.toLowerCase();
                    // Backend already returns correct 'type' field ('folder' for folders)
                    let type = f.type || 'document';

                    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'].includes(extension)) {
                        type = 'image';
                    } else if (['mp4', 'webm', 'mov'].includes(extension)) {
                        type = 'video';
                    } else if (['mp3', 'wav', 'ogg'].includes(extension)) {
                        type = 'audio';
                    }

                    return {
                        ...f,
                        type,
                        is_starred: (prefsData.starred || []).includes(f.id)
                    };
                });

                setFiles(mergedFiles);
            }
        } catch (error) {
            console.error('Error fetching files:', error);
        } finally {
            setIsLoading(false);
        }
    };

    const handleCreateFolder = async (folderName: string) => {
        try {
            const parentPath = currentPath.slice(1).join('/');
            const response = await authFetch(`/api/folders/${companyId}`, {
                method: 'POST',
                body: JSON.stringify({
                    name: folderName,
                    parent_path: parentPath,
                    visibility: fileViewMode  // Auto-set based on current view mode
                }),
            });

            if (response.ok) {
                fetchFiles();
            }
        } catch (error) {
            console.error('Error creating folder:', error);
        }
    };

    const handleCreateFileRequest = async (data: FileRequestData) => {
        try {
            const payload = {
                name: data.name,
                destination_path: data.destination_path,
                expires_in_days: Number(data.expires_in_days),
                visibility: data.visibility,
                ...(data.department_id ? { department_id: data.department_id } : {}),
                ...(data.max_uploads ? { max_uploads: Number(data.max_uploads) } : {}),
            };
            console.log('File request payload:', JSON.stringify(payload, null, 2));
            const response = await authFetch('/api/file-requests', {
                method: 'POST',
                body: JSON.stringify(payload),
            });

            if (response.ok) {
                setIsRequestModalOpen(false);
            } else {
                const errorData = await response.json();
                throw new Error(errorData.error || 'Failed to create file request');
            }
        } catch (error) {
            console.error('Error creating file request:', error);
            // throw error; // Don't throw, just log so modal doesn't crash app
        }
    };
    const handleRename = async (newName: string) => {
        if (!fileToRename) return;
        
        // Check if file is locked
        if (fileToRename.is_locked) {
            alert('Cannot rename a locked file. Please unlock it first.');
            return;
        }
        
        try {
            const response = await authFetch(`/api/files/${companyId}/rename`, {
                method: 'POST',
                body: JSON.stringify({ 
                    old_name: fileToRename.name, 
                    new_name: newName,
                    parent_path: currentPath.slice(1).join('/') // Remove "Home", join rest
                }),
            });

            if (response.ok) {
                fetchFiles();
            }
        } catch (error) {
            console.error('Error renaming file:', error);
        }
    };

    const handleDelete = async (file: FileItem) => {
        if (!confirm(`Are you sure you want to move "${file.name}" to the Recycle Bin?`)) return;

        // Construct full path
        const currentPathStr = currentPath.slice(1).join('/');
        const fullPath = currentPathStr ? `${currentPathStr}/${file.name}` : file.name;

        try {
            const response = await authFetch(`/api/files/${companyId}/delete`, {
                method: 'POST',
                body: JSON.stringify({ path: fullPath })
            });

            if (response.ok) {
                fetchFiles();
            }
        } catch (error) {
            console.error('Error deleting file:', error);
        }
    };

    const toggleStar = async (file: FileItem) => {
        const newStarred = starredFiles.includes(file.id)
            ? starredFiles.filter(id => id !== file.id)
            : [...starredFiles, file.id];

        setStarredFiles(newStarred);

        // Optimistic update
        setFiles(files.map(f => f.id === file.id ? { ...f, is_starred: !f.is_starred } : f));

        try {
            await authFetch(`/api/prefs/${companyId}`, {
                method: 'POST',
                body: JSON.stringify({ starred: newStarred, settings: {} }),
            });
        } catch (error) {
            console.error('Error updating prefs:', error);
            fetchFiles(); // Revert on error
        }
    };

    // Check if user can access a locked file
    const canAccessLockedFile = (file: FileItem) => {
        if (!file.is_locked) return true;
        const isOwner = user?.id === file.owner_id;
        const isLocker = user?.id === file.locked_by;
        const isAdmin = user?.role === 'SuperAdmin' || user?.role === 'Admin' || user?.role === 'Manager';
        return isLocker || isOwner || isAdmin;
    };

    const handlePreview = (file: FileItem) => {
        // SECURITY: Check if user can access locked file before preview
        if (!canAccessLockedFile(file)) {
            // Show a toast or alert that file is locked
            console.warn('Cannot preview locked file - access denied');
            return;
        }
        setPreviewFile({
            name: file.name,
            url: `/api/download/${companyId}/${file.id}`,
            type: file.type
        });
    };

    const handleShare = (file: FileItem) => {
        setShareFile(file);
        setIsShareModalOpen(true);
        setActiveMenu(null);
    };

    const handleDownload = async (file: FileItem) => {
        if (!companyId) return;
        
        // SECURITY: Check if user can access locked file before download
        if (!canAccessLockedFile(file)) {
            console.warn('Cannot download locked file - access denied');
            return;
        }
        
        try {
            // SECURITY: Use header-based auth instead of token-in-URL
            // Folders are automatically downloaded as zip archives
            const response = await authFetch(`/api/download/${companyId}/${file.id}`);
            if (!response.ok) {
                throw new Error('Download failed');
            }
            const blob = await response.blob();
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            // For folders, add .zip extension
            const downloadName = file.type === 'folder' ? `${file.name}.zip` : file.name;
            a.download = downloadName;
            document.body.appendChild(a);
            a.click();
            window.URL.revokeObjectURL(url);
            document.body.removeChild(a);
        } catch (error) {
            console.error('Download error:', error);
            alert('Failed to download ' + (file.type === 'folder' ? 'folder' : 'file'));
        }
        setActiveMenu(null);
    };

    const handleLockToggle = (file: FileItem) => {
        setLockingFile(file);
        setActiveMenu(null);
        if (file.is_locked) {
            setIsUnlockModalOpen(true);
        } else {
            setIsLockModalOpen(true);
        }
    };

    const handleLockFile = async (password: string | null, requiredRole: string | null) => {
        if (!lockingFile || !companyId) return;
        setIsLocking(true);
        try {
            const response = await authFetch(`/api/files/${companyId}/${lockingFile.id}/lock`, {
                method: 'POST',
                body: JSON.stringify({
                    password: password,
                    required_role: requiredRole
                })
            });

            if (response.ok) {
                fetchFiles();
                setIsLockModalOpen(false);
                setLockingFile(null);
            } else {
                const error = await response.json();
                throw new Error(error.error || 'Failed to lock file');
            }
        } finally {
            setIsLocking(false);
        }
    };

    const handleUnlockFile = async (password: string | null): Promise<{ error?: string; requires_password?: boolean }> => {
        if (!lockingFile || !companyId) return { error: 'No file selected' };
        setIsLocking(true);
        try {
            const response = await authFetch(`/api/files/${companyId}/${lockingFile.id}/unlock`, {
                method: 'POST',
                body: JSON.stringify({ password })
            });

            const result = await response.json();
            
            if (response.ok && !result.error) {
                fetchFiles();
                setIsUnlockModalOpen(false);
                setLockingFile(null);
                return {};
            } else {
                return { 
                    error: result.error || 'Failed to unlock file',
                    requires_password: result.requires_password
                };
            }
        } finally {
            setIsLocking(false);
        }
    };

    const handleMoveFile = async (targetParentId: string | null, targetDepartmentId: string | null, targetVisibility: string = 'department') => {
        if (!movingFile || !companyId) return;
        setIsMoving(true);
        try {
            const response = await authFetch(`/api/files/${companyId}/${movingFile.id}/move`, {
                method: 'PUT',
                body: JSON.stringify({
                    target_parent_id: targetParentId,
                    target_department_id: targetDepartmentId,
                    target_visibility: targetVisibility
                })
            });

            const result = await response.json();
            
            if (!response.ok || result.error) {
                throw new Error(result.error || result.message || 'Failed to move file');
            }
            
            fetchFiles();
            setIsMoveModalOpen(false);
            setMovingFile(null);
        } finally {
            setIsMoving(false);
        }
    };

    const openMoveModal = (file: FileItem) => {
        setMovingFile(file);
        setIsMoveModalOpen(true);
        setActiveMenu(null);
    };

    // Drag and drop handlers
    const handleDragStart = (e: React.DragEvent, file: FileItem) => {
        if (file.is_locked) {
            e.preventDefault();
            return;
        }
        setDraggedFile(file);
        e.dataTransfer.effectAllowed = 'move';
        e.dataTransfer.setData('text/plain', file.id);
    };

    const handleDragOver = (e: React.DragEvent, targetId: string | null) => {
        e.preventDefault();
        if (draggedFile && draggedFile.id !== targetId) {
            setDropTargetId(targetId);
            e.dataTransfer.dropEffect = 'move';
        }
    };

    const handleDragLeave = () => {
        setDropTargetId(null);
    };

    const handleMoveFileDrop = async (e: React.DragEvent, targetParentId: string | null) => {
        e.preventDefault();
        setDropTargetId(null);
        
        if (!draggedFile || !companyId) {
            setDraggedFile(null);
            return;
        }

        // Don't drop on itself or if locked
        if (draggedFile.id === targetParentId || draggedFile.is_locked) {
            setDraggedFile(null);
            return;
        }

        try {
            const response = await authFetch(`/api/files/${companyId}/${draggedFile.id}/move`, {
                method: 'PUT',
                body: JSON.stringify({
                    target_parent_id: targetParentId,
                    target_department_id: null
                })
            });

            const result = await response.json();
            
            if (!response.ok || result.error) {
                alert(result.error || result.message || 'Failed to move file');
            } else {
                fetchFiles();
            }
        } catch (error) {
            console.error('Error moving file:', error);
        }
        
        setDraggedFile(null);
    };

    const handleDragEnd = () => {
        setDraggedFile(null);
        setDropTargetId(null);
    };

    const handleViewActivity = (file: FileItem) => {
        setActivityFile(file);
        setIsActivityModalOpen(true);
        setActiveMenu(null);
    };

    const handleViewProperties = (file: FileItem) => {
        setPropertiesFile(file);
        setIsPropertiesModalOpen(true);
        setActiveMenu(null);
    };

    const handleToggleCompanyFolder = async (file: FileItem) => {
        if (!companyId || file.type !== 'folder') return;
        
        try {
            const response = await authFetch(`/api/files/${companyId}/${file.id}/company-folder`, {
                method: 'PUT',
            });
            
            if (response.ok) {
                // Refresh file list to get updated state
                fetchFiles();
            } else {
                console.error('Failed to toggle company folder status');
            }
        } catch (error) {
            console.error('Error toggling company folder:', error);
        }
        setActiveMenu(null);
    };

    // Permission checks
    const canLockFiles = user?.role === 'SuperAdmin' || user?.role === 'Admin' || user?.role === 'Manager';
    const canViewActivity = user?.role === 'SuperAdmin' || user?.role === 'Admin';
    const isAdminOrHigher = user?.role === 'SuperAdmin' || user?.role === 'Admin';
    
    // File-level permission checks
    const canDeleteFile = (file: FileItem) => {
        if (file.is_locked) return false;
        if (isAdminOrHigher) return true;
        return file.owner_id === user?.id;
    };
    
    // Share permission: owner, manager, or admin can share
    const canShareFile = (file: FileItem) => {
        if (isAdminOrHigher) return true;
        if (user?.role === 'Manager') return true;
        return file.owner_id === user?.id;
    };
    
    const canMoveFile = (file: FileItem) => {
        if (file.is_locked) return false;
        // All users can move unlocked files within their access scope
        return true;
    };
    
    // Get files that can be deleted/moved from selection
    const getSelectedFilesForAction = (action: 'delete' | 'move') => {
        const selectedFilesList = files.filter(f => selectedFiles.has(f.id));
        if (action === 'delete') {
            return selectedFilesList.filter(canDeleteFile);
        }
        return selectedFilesList.filter(canMoveFile);
    };
    
    const deletableSelectedFiles = getSelectedFilesForAction('delete');
    const movableSelectedFiles = getSelectedFilesForAction('move');

    const [sortBy, setSortBy] = useState<'name' | 'size' | 'modified'>('modified');
    const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
    const [searchQuery, setSearchQuery] = useState('');
    
    // Pagination
    const [currentPage, setCurrentPage] = useState(1);

    // Check if any modal is open (disable shortcuts when modals are open)
    const isAnyModalOpen = isRenameOpen || isNewFolderOpen || isActivityModalOpen || 
        isLockModalOpen || isUnlockModalOpen || isMoveModalOpen || 
        isPropertiesModalOpen || isShareModalOpen || isRequestModalOpen || 
        isUploadModalOpen || isBulkMoveModalOpen || previewFile !== null;

    // Keyboard shortcuts for file operations - read from preset context
    const { getResolvedBinding } = useKeyboardShortcutsContext();
    
    // Helper to get binding from current preset
    const getBinding = useCallback((actionId: ShortcutActionId) => {
        const binding = getResolvedBinding(actionId);
        return binding ? { keys: binding.keys, isSequence: binding.isSequence } : null;
    }, [getResolvedBinding]);

    const fileShortcuts: Shortcut[] = useMemo(() => {
        const shortcuts: Shortcut[] = [];
        
        // Upload files
        const uploadBinding = getBinding('file.upload');
        if (uploadBinding) {
            shortcuts.push({
                id: 'file.upload',
                keys: uploadBinding.keys,
                description: 'Upload files',
                category: 'files',
                action: () => {
                    if (!isAnyModalOpen) {
                        fileInputRef.current?.click();
                    }
                },
                enabled: !isAnyModalOpen,
                isSequence: uploadBinding.isSequence,
            });
        }
        
        // New folder
        const newFolderBinding = getBinding('file.newFolder');
        if (newFolderBinding) {
            shortcuts.push({
                id: 'file.newFolder',
                keys: newFolderBinding.keys,
                description: 'Create new folder',
                category: 'files',
                action: () => {
                    if (!isAnyModalOpen) {
                        setIsNewFolderOpen(true);
                    }
                },
                enabled: !isAnyModalOpen,
                isSequence: newFolderBinding.isSequence,
            });
        }
        
        // Delete selected
        const deleteBinding = getBinding('file.delete');
        if (deleteBinding) {
            shortcuts.push({
                id: 'file.delete',
                keys: deleteBinding.keys,
                description: 'Delete selected files',
                category: 'files',
                action: () => {
                    if (!isAnyModalOpen && selectedFiles.size > 0) {
                        handleBulkDelete();
                    }
                },
                enabled: !isAnyModalOpen && selectedFiles.size > 0,
                isSequence: deleteBinding.isSequence,
            });
        }
        
        // Rename selected file
        const renameBinding = getBinding('file.rename');
        if (renameBinding) {
            shortcuts.push({
                id: 'file.rename',
                keys: renameBinding.keys,
                description: 'Rename selected file',
                category: 'files',
                action: () => {
                    if (!isAnyModalOpen && selectedFiles.size === 1) {
                        const fileId = Array.from(selectedFiles)[0];
                        const file = files.find(f => f.id === fileId);
                        if (file && !file.is_locked && !file.is_company_folder) {
                            setFileToRename(file);
                            setIsRenameOpen(true);
                        }
                    }
                },
                enabled: !isAnyModalOpen && selectedFiles.size === 1,
                isSequence: renameBinding.isSequence,
            });
        }
        
        // Move selected files
        const moveBinding = getBinding('file.move');
        if (moveBinding) {
            shortcuts.push({
                id: 'file.move',
                keys: moveBinding.keys,
                description: 'Move selected files',
                category: 'files',
                action: () => {
                    if (!isAnyModalOpen && selectedFiles.size > 0 && movableSelectedFiles.length > 0) {
                        setIsBulkMoveModalOpen(true);
                    }
                },
                enabled: !isAnyModalOpen && movableSelectedFiles.length > 0,
                isSequence: moveBinding.isSequence,
            });
        }
        
        // Open/enter
        const openBinding = getBinding('file.open');
        if (openBinding) {
            shortcuts.push({
                id: 'file.open',
                keys: openBinding.keys,
                description: 'Open file or enter folder',
                category: 'files',
                action: () => {
                    if (!isAnyModalOpen && focusedFileIndex >= 0 && focusedFileIndex < files.length) {
                        const file = files[focusedFileIndex];
                        if (file) {
                            if (file.type === 'folder') {
                                setCurrentPath([...currentPath, file.name]);
                            } else {
                                handlePreview(file);
                            }
                        }
                    }
                },
                enabled: !isAnyModalOpen && focusedFileIndex >= 0,
                isSequence: openBinding.isSequence,
            });
        }
        
        // Download
        const downloadBinding = getBinding('file.download');
        if (downloadBinding) {
            shortcuts.push({
                id: 'file.download',
                keys: downloadBinding.keys,
                description: 'Download focused file',
                category: 'files',
                action: () => {
                    if (!isAnyModalOpen && focusedFileIndex >= 0 && focusedFileIndex < files.length) {
                        const file = files[focusedFileIndex];
                        if (file) {
                            handleDownload(file);
                        }
                    }
                },
                enabled: !isAnyModalOpen && focusedFileIndex >= 0,
                isSequence: downloadBinding.isSequence,
            });
        }
        
        // Preview
        const previewBinding = getBinding('file.preview');
        if (previewBinding) {
            shortcuts.push({
                id: 'file.preview',
                keys: previewBinding.keys,
                description: 'Preview file',
                category: 'files',
                action: () => {
                    if (!isAnyModalOpen && focusedFileIndex >= 0 && focusedFileIndex < files.length) {
                        const file = files[focusedFileIndex];
                        if (file && file.type !== 'folder') {
                            handlePreview(file);
                        }
                    }
                },
                enabled: !isAnyModalOpen && focusedFileIndex >= 0,
                isSequence: previewBinding.isSequence,
            });
        }
        
        // Select all
        const selectAllBinding = getBinding('select.all');
        if (selectAllBinding) {
            shortcuts.push({
                id: 'select.all',
                keys: selectAllBinding.keys,
                description: 'Select all files',
                category: 'selection',
                action: () => {
                    if (!isAnyModalOpen) {
                        selectAllFiles();
                        setIsSelectionMode(true);
                    }
                },
                enabled: !isAnyModalOpen,
                isSequence: selectAllBinding.isSequence,
            });
        }
        
        // Toggle selection
        const toggleBinding = getBinding('select.toggle');
        if (toggleBinding) {
            shortcuts.push({
                id: 'select.toggle',
                keys: toggleBinding.keys,
                description: 'Toggle selection on focused item',
                category: 'selection',
                action: () => {
                    if (!isAnyModalOpen && focusedFileIndex >= 0 && focusedFileIndex < files.length) {
                        const file = files[focusedFileIndex];
                        if (file) {
                            toggleFileSelection(file.id);
                            setIsSelectionMode(true);
                        }
                    }
                },
                enabled: !isAnyModalOpen && focusedFileIndex >= 0,
                isSequence: toggleBinding.isSequence,
            });
        }
        
        // Navigate up
        const upBinding = getBinding('select.up');
        if (upBinding) {
            shortcuts.push({
                id: 'select.up',
                keys: upBinding.keys,
                description: 'Move focus up',
                category: 'selection',
                action: () => {
                    if (!isAnyModalOpen) {
                        setFocusedFileIndex(prev => {
                            if (prev > 0) return prev - 1;
                            if (prev === -1 && files.length > 0) return 0;
                            return prev;
                        });
                    }
                },
                enabled: !isAnyModalOpen,
                isSequence: upBinding.isSequence,
            });
        }
        
        // Navigate down
        const downBinding = getBinding('select.down');
        if (downBinding) {
            shortcuts.push({
                id: 'select.down',
                keys: downBinding.keys,
                description: 'Move focus down',
                category: 'selection',
                action: () => {
                    if (!isAnyModalOpen) {
                        setFocusedFileIndex(prev => {
                            if (prev < files.length - 1) return prev + 1;
                            return prev;
                        });
                    }
                },
                enabled: !isAnyModalOpen,
                isSequence: downBinding.isSequence,
            });
        }
        
        // Navigate left
        const leftBinding = getBinding('select.left');
        if (leftBinding) {
            shortcuts.push({
                id: 'select.left',
                keys: leftBinding.keys,
                description: 'Move focus left',
                category: 'selection',
                action: () => {
                    if (!isAnyModalOpen && viewMode === 'grid') {
                        setFocusedFileIndex(prev => {
                            if (prev > 0) return prev - 1;
                            if (prev === -1 && files.length > 0) return 0;
                            return prev;
                        });
                    }
                },
                enabled: !isAnyModalOpen && viewMode === 'grid',
                isSequence: leftBinding.isSequence,
            });
        }
        
        // Navigate right
        const rightBinding = getBinding('select.right');
        if (rightBinding) {
            shortcuts.push({
                id: 'select.right',
                keys: rightBinding.keys,
                description: 'Move focus right',
                category: 'selection',
                action: () => {
                    if (!isAnyModalOpen && viewMode === 'grid') {
                        setFocusedFileIndex(prev => {
                            if (prev < files.length - 1) return prev + 1;
                            return prev;
                        });
                    }
                },
                enabled: !isAnyModalOpen && viewMode === 'grid',
                isSequence: rightBinding.isSequence,
            });
        }
        
        return shortcuts;
    }, [isAnyModalOpen, selectedFiles, files, focusedFileIndex, movableSelectedFiles, viewMode, currentPath, getBinding]);

    useKeyboardShortcuts(fileShortcuts, { enabled: !isAnyModalOpen });

    // Reset focused index when files change
    useEffect(() => {
        setFocusedFileIndex(-1);
    }, [files.length, currentPath]);

    const getIcon = (type: FileItem['type']) => {
        switch (type) {
            case 'folder': return <Folder className="w-16 h-16 text-blue-500" />;
            case 'image': return <ImageIcon className="w-16 h-16 text-purple-500" />;
            case 'video': return <ImageIcon className="w-16 h-16 text-red-500" />;
            case 'audio': return <ImageIcon className="w-16 h-16 text-yellow-500" />;
            default: return <FileText className="w-16 h-16 text-gray-500" />;
        }
    };

    // Smaller icons for Quick Access section
    const getSmallIcon = (type: FileItem['type']) => {
        switch (type) {
            case 'folder': return <Folder className="w-8 h-8 text-blue-500" />;
            case 'image': return <ImageIcon className="w-8 h-8 text-purple-500" />;
            case 'video': return <ImageIcon className="w-8 h-8 text-red-500" />;
            case 'audio': return <ImageIcon className="w-8 h-8 text-yellow-500" />;
            default: return <FileText className="w-8 h-8 text-gray-500" />;
        }
    };

    const handleDrag = (e: React.DragEvent) => {
        e.preventDefault();
        e.stopPropagation();

        // Ignore if we are dragging an internal file
        if (draggedFile) return;

        if (e.type === "dragenter" || e.type === "dragover") {
            setIsDragging(true);
        } else if (e.type === "dragleave") {
            setIsDragging(false);
        }
    };

    const handleDrop = async (e: React.DragEvent) => {
        e.preventDefault();
        e.stopPropagation();

        // Ignore if we are dragging an internal file
        if (draggedFile) return;

        setIsDragging(false);

        const files = Array.from(e.dataTransfer.files);
        if (files.length > 0) {
            await startUpload(files);
        }
    };

    const handleFileInput = async (e: React.ChangeEvent<HTMLInputElement>) => {
        if (e.target.files && e.target.files.length > 0) {
            await startUpload(Array.from(e.target.files));
        }
    };

    const startUpload = async (files: File[]) => {
        const newUploads: UploadFile[] = files.map(f => ({
            file: f,
            progress: 0,
            status: 'pending'
        }));

        setUploadFilesList(newUploads);
        setIsUploadModalOpen(true);

        for (let i = 0; i < newUploads.length; i++) {
            const uploadItem = newUploads[i];
            setUploadFilesList(prev => prev.map((item, idx) => idx === i ? { ...item, status: 'uploading' } : item));

            const formData = new FormData();
            formData.append('file', uploadItem.file);

            try {
                // Mock progress
                for (let p = 0; p <= 90; p += 30) {
                    await new Promise(r => setTimeout(r, 200));
                    setUploadFilesList(prev => prev.map((item, idx) => idx === i ? { ...item, progress: p } : item));
                }

                // Get current path (strip "Home")
                const parentPath = currentPath.slice(1).join('/');
                const queryParams = new URLSearchParams();
                if (parentPath) queryParams.set('parent_path', parentPath);
                // Auto-set visibility based on current view mode
                if (fileViewMode === 'private') queryParams.set('visibility', 'private');
                const queryString = queryParams.toString();
                const uploadUrl = `${import.meta.env.VITE_API_URL || ''}/api/upload/${companyId}${queryString ? `?${queryString}` : ''}`;

                // Note: authFetch sets Content-Type to application/json by default, but for FormData we need to let browser set it
                // So we override headers to remove Content-Type
                const response = await authFetch(uploadUrl, {
                    method: 'POST',
                    headers: {
                        // Remove Content-Type to let browser set boundary for FormData
                        'Content-Type': undefined as any
                    },
                    body: formData,
                });

                if (response.ok) {
                    const data = await response.json();
                    // Check for blocked extension error (returned as 200 with error field)
                    if (data.error === 'blocked_extension') {
                        const errorMsg = data.message || `File type .${data.extension} is not allowed`;
                        setUploadFilesList(prev => prev.map((item, idx) => idx === i ? { ...item, status: 'error', error: errorMsg } : item));
                        alert(errorMsg);
                    } else {
                        setUploadFilesList(prev => prev.map((item, idx) => idx === i ? { ...item, status: 'completed', progress: 100 } : item));
                        fetchFiles();
                    }
                } else {
                    throw new Error('Upload failed');
                }
            } catch (error) {
                console.error(error);
                setUploadFilesList(prev => prev.map((item, idx) => idx === i ? { ...item, status: 'error', error: 'Failed' } : item));
            }
        }
    };

    const filteredFiles = files
        .filter(f => f.name.toLowerCase().includes(searchQuery.toLowerCase()))
        .sort((a, b) => {
            // Always show folders first
            const aIsFolder = a.type === 'folder';
            const bIsFolder = b.type === 'folder';
            if (aIsFolder && !bIsFolder) return -1;
            if (!aIsFolder && bIsFolder) return 1;
            
            // Then apply normal sort criteria
            let comparison = 0;
            if (sortBy === 'name') {
                comparison = a.name.localeCompare(b.name);
            } else if (sortBy === 'size') {
                comparison = (a.size_bytes || 0) - (b.size_bytes || 0);
            } else if (sortBy === 'modified') {
                comparison = new Date(a.modified).getTime() - new Date(b.modified).getTime();
            }
            return sortOrder === 'asc' ? comparison : -comparison;
        });

    // Pagination calculations
    const totalPages = Math.ceil(filteredFiles.length / itemsPerPage);
    const paginatedFiles = filteredFiles.slice(
        (currentPage - 1) * itemsPerPage,
        currentPage * itemsPerPage
    );

    // Reset to page 1 when search query or path changes
    useEffect(() => {
        setCurrentPage(1);
    }, [searchQuery, currentPath]);

    const handleSort = (key: 'name' | 'size' | 'modified') => {
        if (sortBy === key) {
            setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
        } else {
            setSortBy(key);
            setSortOrder('asc');
        }
    };

    const [draggedFile, setDraggedFile] = useState<FileItem | null>(null);

    const handleFileDragStart = (e: React.DragEvent, file: FileItem) => {
        e.stopPropagation();
        setDraggedFile(file);
        e.dataTransfer.setData('application/json', JSON.stringify(file));
        e.dataTransfer.effectAllowed = 'move';
    };

    const handleFolderDragOver = (e: React.DragEvent, folder: FileItem) => {
        e.preventDefault();
        e.stopPropagation();
        if (draggedFile && draggedFile.id !== folder.id && folder.type === 'folder') {
            e.dataTransfer.dropEffect = 'move';
            e.currentTarget.classList.add('bg-primary-100', 'border-primary-500');
        }
    };

    const handleFolderDragLeave = (e: React.DragEvent) => {
        e.preventDefault();
        e.stopPropagation();
        e.currentTarget.classList.remove('bg-primary-100', 'border-primary-500');
    };

    const handleFolderDrop = async (e: React.DragEvent, folder: FileItem) => {
        e.preventDefault();
        e.stopPropagation();
        e.currentTarget.classList.remove('bg-primary-100', 'border-primary-500');

        if (!draggedFile || draggedFile.id === folder.id || draggedFile.is_locked) return;

        // Optimistic update
        setFiles(prev => prev.filter(f => f.id !== draggedFile.id));
        const draggedFileBackup = draggedFile;
        setDraggedFile(null);

        try {
            // Use the new move API endpoint with folder ID
            const response = await authFetch(`/api/files/${companyId}/${draggedFileBackup.id}/move`, {
                method: 'PUT',
                body: JSON.stringify({ 
                    target_parent_id: folder.id,
                    target_department_id: null
                }),
            });

            const result = await response.json();
            
            if (!response.ok || result.error) {
                alert(result.error || result.message || 'Failed to move file');
                fetchFiles(); // Revert
                return;
            }

            // Refresh to ensure everything is synced
            fetchFiles();
        } catch (error) {
            console.error('Error moving file:', error);
            fetchFiles(); // Revert
        }
    };

    return (
        <div className="h-full flex flex-col space-y-3 sm:space-y-4">
            {/* Header & Actions */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 sm:gap-4 mb-1 sm:mb-2">
                <div>
                    <h1 className="text-xl sm:text-2xl font-bold text-gray-900 dark:text-white">Files</h1>
                    <p className="text-xs sm:text-sm text-gray-500 dark:text-gray-400 mt-0.5 sm:mt-1">Manage your company documents and assets</p>
                </div>
                <div className="flex space-x-3">
                    {/* View Mode Switcher */}
                    <div className="relative" ref={viewModeRef}>
                        <button
                            onClick={(e) => { e.stopPropagation(); setIsViewModeOpen(!isViewModeOpen); }}
                            className="flex items-center px-4 py-2 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-lg text-sm font-medium text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-700 shadow-sm"
                        >
                            {fileViewMode === 'private' ? (
                                <><EyeOff className="w-4 h-4 mr-2 text-purple-500" />My Private Files</>
                            ) : selectedDepartment ? (
                                <><Building2 className="w-4 h-4 mr-2 text-green-500" />{departments.find(d => d.id === selectedDepartment)?.name || 'Department'}</>
                            ) : (
                                <><Users className="w-4 h-4 mr-2 text-blue-500" />All Departments</>
                            )}
                            <ChevronDown className="w-4 h-4 ml-2 text-gray-400" />
                        </button>
                        {isViewModeOpen && (
                            <div className="absolute left-0 mt-2 w-56 bg-white dark:bg-gray-800 rounded-lg shadow-lg py-1 ring-1 ring-black ring-opacity-5 z-50 border border-gray-200 dark:border-gray-700 max-h-80 overflow-y-auto">
                                {/* All Departments option */}
                                <button
                                    onClick={() => { setFileViewMode('department'); setSelectedDepartment(null); setIsViewModeOpen(false); }}
                                    className={clsx(
                                        "flex items-center w-full px-4 py-2.5 text-sm text-gray-700 dark:text-gray-200 hover:bg-gray-100 dark:hover:bg-gray-700",
                                        fileViewMode === 'department' && !selectedDepartment && "bg-gray-50 dark:bg-gray-700 font-medium"
                                    )}
                                >
                                    <Users className="w-4 h-4 mr-3 text-blue-500" />
                                    All Departments
                                    {fileViewMode === 'department' && !selectedDepartment && <span className="ml-auto text-primary-500">✓</span>}
                                </button>
                                
                                {/* Individual department options for admins */}
                                {departments.length > 0 && (user?.role === 'Admin' || user?.role === 'SuperAdmin') && (
                                    <>
                                        <div className="border-t border-gray-200 dark:border-gray-700 my-1" />
                                        <div className="px-4 py-1.5 text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                                            Filter by Department
                                        </div>
                                        {departments.map((dept) => (
                                            <button
                                                key={dept.id}
                                                onClick={() => { setFileViewMode('department'); setSelectedDepartment(dept.id); setIsViewModeOpen(false); }}
                                                className={clsx(
                                                    "flex items-center w-full px-4 py-2.5 text-sm text-gray-700 dark:text-gray-200 hover:bg-gray-100 dark:hover:bg-gray-700",
                                                    fileViewMode === 'department' && selectedDepartment === dept.id && "bg-gray-50 dark:bg-gray-700 font-medium"
                                                )}
                                            >
                                                <Building2 className="w-4 h-4 mr-3 text-green-500" />
                                                {dept.name}
                                                {fileViewMode === 'department' && selectedDepartment === dept.id && <span className="ml-auto text-primary-500">✓</span>}
                                            </button>
                                        ))}
                                    </>
                                )}
                                
                                <div className="border-t border-gray-200 dark:border-gray-700 my-1" />
                                <button
                                    onClick={() => { setFileViewMode('private'); setSelectedDepartment(null); setIsViewModeOpen(false); }}
                                    className={clsx(
                                        "flex items-center w-full px-4 py-2.5 text-sm text-gray-700 dark:text-gray-200 hover:bg-gray-100 dark:hover:bg-gray-700",
                                        fileViewMode === 'private' && "bg-gray-50 dark:bg-gray-700 font-medium"
                                    )}
                                >
                                    <EyeOff className="w-4 h-4 mr-3 text-purple-500" />
                                    My Private Files
                                    {fileViewMode === 'private' && <span className="ml-auto text-primary-500">✓</span>}
                                </button>
                            </div>
                        )}
                    </div>
                    {/* Desktop: Individual icon buttons */}
                    <div className="hidden sm:flex items-center space-x-2">
                        {/* Select Mode Toggle */}
                        <button
                            onClick={() => {
                                if (isSelectionMode) {
                                    clearSelection();
                                } else {
                                    setIsSelectionMode(true);
                                }
                            }}
                            title={isSelectionMode ? 'Cancel selection' : 'Select files'}
                            className={clsx(
                                "p-2.5 border rounded-lg shadow-sm transition-colors",
                                isSelectionMode 
                                    ? "bg-primary-50 dark:bg-primary-900/20 border-primary-300 dark:border-primary-700 text-primary-700 dark:text-primary-300" 
                                    : "bg-white dark:bg-gray-800 border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-700"
                            )}
                        >
                            {isSelectionMode ? <X className="w-5 h-5" /> : <CheckSquare className="w-5 h-5" />}
                        </button>
                        <Link
                            to="/recycle-bin"
                            title="Recycle Bin"
                            className="p-2.5 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-700 shadow-sm transition-colors"
                        >
                            <Trash2 className="w-5 h-5" />
                        </Link>
                        <button
                            onClick={() => setIsRequestModalOpen(true)}
                            title="Request Files"
                            className="p-2.5 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-700 shadow-sm transition-colors"
                        >
                            <LinkIcon className="w-5 h-5" />
                        </button>
                        <button
                            onClick={() => setIsNewFolderOpen(true)}
                            title="New Folder"
                            className="p-2.5 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-700 shadow-sm transition-colors"
                        >
                            <FolderPlus className="w-5 h-5" />
                        </button>
                    </div>
                    
                    {/* Mobile: Overflow menu */}
                    <div className="sm:hidden relative" ref={mobileMenuRef}>
                        <button
                            onClick={(e) => { e.stopPropagation(); setIsMobileMenuOpen(!isMobileMenuOpen); }}
                            className="p-2.5 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-700 shadow-sm transition-colors"
                        >
                            <MoreHorizontal className="w-5 h-5" />
                        </button>
                        {isMobileMenuOpen && (
                            <div className="absolute right-0 mt-2 w-48 bg-white dark:bg-gray-800 rounded-lg shadow-lg py-1 ring-1 ring-black ring-opacity-5 z-50 border border-gray-200 dark:border-gray-700">
                                <button
                                    onClick={() => {
                                        if (isSelectionMode) {
                                            clearSelection();
                                        } else {
                                            setIsSelectionMode(true);
                                        }
                                        setIsMobileMenuOpen(false);
                                    }}
                                    className="flex items-center w-full px-4 py-3 text-sm text-gray-700 dark:text-gray-200 hover:bg-gray-100 dark:hover:bg-gray-700"
                                >
                                    {isSelectionMode ? <X className="w-5 h-5 mr-3" /> : <CheckSquare className="w-5 h-5 mr-3" />}
                                    {isSelectionMode ? 'Cancel Selection' : 'Select Files'}
                                </button>
                                <Link
                                    to="/recycle-bin"
                                    onClick={() => setIsMobileMenuOpen(false)}
                                    className="flex items-center w-full px-4 py-3 text-sm text-gray-700 dark:text-gray-200 hover:bg-gray-100 dark:hover:bg-gray-700"
                                >
                                    <Trash2 className="w-5 h-5 mr-3" />
                                    Recycle Bin
                                </Link>
                                <button
                                    onClick={() => { setIsRequestModalOpen(true); setIsMobileMenuOpen(false); }}
                                    className="flex items-center w-full px-4 py-3 text-sm text-gray-700 dark:text-gray-200 hover:bg-gray-100 dark:hover:bg-gray-700"
                                >
                                    <LinkIcon className="w-5 h-5 mr-3" />
                                    Request Files
                                </button>
                                <button
                                    onClick={() => { setIsNewFolderOpen(true); setIsMobileMenuOpen(false); }}
                                    className="flex items-center w-full px-4 py-3 text-sm text-gray-700 dark:text-gray-200 hover:bg-gray-100 dark:hover:bg-gray-700"
                                >
                                    <FolderPlus className="w-5 h-5 mr-3" />
                                    New Folder
                                </button>
                            </div>
                        )}
                    </div>
                    
                    <input
                        type="file"
                        ref={fileInputRef}
                        className="hidden"
                        multiple
                        onChange={handleFileInput}
                    />
                    <button
                        onClick={() => fileInputRef.current?.click()}
                        className="flex items-center px-3 sm:px-4 py-2 bg-primary-600 rounded-lg text-sm font-medium text-white hover:bg-primary-700 shadow-sm"
                    >
                        <Upload className="w-4 h-4 sm:mr-2" />
                        <span className="hidden sm:inline">Upload File</span>
                    </button>
                </div>
            </div>

            {/* Bulk Action Bar */}
            {selectedFiles.size > 0 && (
                <div className="flex items-center justify-between px-4 py-3 bg-primary-50 dark:bg-primary-900/20 border border-primary-200 dark:border-primary-800 rounded-lg">
                    <div className="flex items-center gap-4">
                        <span className="text-sm font-medium text-primary-700 dark:text-primary-300">
                            {selectedFiles.size} item{selectedFiles.size !== 1 ? 's' : ''} selected
                        </span>
                        {/* Show permission info if some files can't be acted on */}
                        {(movableSelectedFiles.length < selectedFiles.size || deletableSelectedFiles.length < selectedFiles.size) && (
                            <span className="text-xs text-amber-600 dark:text-amber-400">
                                ({selectedFiles.size - movableSelectedFiles.length} locked)
                            </span>
                        )}
                        <button
                            onClick={selectAllFiles}
                            className="text-sm text-primary-600 dark:text-primary-400 hover:underline"
                        >
                            Select all
                        </button>
                    </div>
                    <div className="flex items-center gap-2">
                        <button
                            onClick={() => {
                                if (movableSelectedFiles.length === 0) {
                                    alert('Cannot move any of the selected files. Locked files cannot be moved.');
                                    return;
                                }
                                setIsBulkMoveModalOpen(true);
                            }}
                            disabled={movableSelectedFiles.length === 0}
                            className={clsx(
                                "flex items-center px-3 py-1.5 border rounded-lg text-sm font-medium",
                                movableSelectedFiles.length > 0
                                    ? "bg-white dark:bg-gray-800 border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-700"
                                    : "bg-gray-100 dark:bg-gray-800 border-gray-200 dark:border-gray-700 text-gray-400 dark:text-gray-500 cursor-not-allowed"
                            )}
                            title={movableSelectedFiles.length === 0 ? 'No movable files selected' : `Move ${movableSelectedFiles.length} file(s)`}
                        >
                            <Move className="w-4 h-4 mr-1.5" />
                            Move{movableSelectedFiles.length < selectedFiles.size && movableSelectedFiles.length > 0 && ` (${movableSelectedFiles.length})`}
                        </button>
                        <button
                            onClick={handleBulkDelete}
                            disabled={deletableSelectedFiles.length === 0}
                            className={clsx(
                                "flex items-center px-3 py-1.5 border rounded-lg text-sm font-medium",
                                deletableSelectedFiles.length > 0
                                    ? "bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800 text-red-700 dark:text-red-300 hover:bg-red-100 dark:hover:bg-red-900/30"
                                    : "bg-gray-100 dark:bg-gray-800 border-gray-200 dark:border-gray-700 text-gray-400 dark:text-gray-500 cursor-not-allowed"
                            )}
                            title={deletableSelectedFiles.length === 0 ? 'No deletable files selected (locked or no permission)' : `Delete ${deletableSelectedFiles.length} file(s)`}
                        >
                            <Trash2 className="w-4 h-4 mr-1.5" />
                            Delete{deletableSelectedFiles.length < selectedFiles.size && deletableSelectedFiles.length > 0 && ` (${deletableSelectedFiles.length})`}
                        </button>
                        <button
                            onClick={clearSelection}
                            className="p-1.5 text-gray-500 hover:text-gray-700 dark:hover:text-gray-300"
                        >
                            <X className="w-4 h-4" />
                        </button>
                    </div>
                </div>
            )}

            {/* Quick Access */}
            {(() => {
                const starredItems = files.filter(f => f.is_starred);
                const visibleStarred = starredItems.slice(0, 4);
                const overflowStarred = starredItems.slice(4);
                const hasOverflow = overflowStarred.length > 0;

                if (starredItems.length === 0) return null;

                return (
                    <div className="mb-4">
                        <div className="flex items-center justify-between mb-3">
                            <h2 className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Quick Access</h2>
                            {hasOverflow && (
                                <div className="relative" ref={starredDropdownRef}>
                                    <button
                                        onClick={() => setShowMoreStarred(!showMoreStarred)}
                                        className="flex items-center text-xs font-medium text-primary-600 dark:text-primary-400 hover:text-primary-700 dark:hover:text-primary-300 transition-colors"
                                    >
                                        +{overflowStarred.length} more
                                        <ChevronDown className={clsx("w-4 h-4 ml-1 transition-transform", showMoreStarred && "rotate-180")} />
                                    </button>
                                    {showMoreStarred && (
                                        <div className="absolute right-0 top-full mt-2 w-72 bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 shadow-xl z-30 max-h-80 overflow-y-auto">
                                            <div className="p-2">
                                                <p className="text-xs text-gray-500 dark:text-gray-400 px-2 py-1 mb-1">More starred items</p>
                                                {overflowStarred.map(file => (
                                                    <div 
                                                        key={`overflow-${file.id}`} 
                                                        className="flex items-center space-x-3 p-2 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700/50 cursor-pointer transition-colors"
                                                        onClick={() => {
                                                            setShowMoreStarred(false);
                                                            if (file.type === 'folder') {
                                                                setCurrentPath([...currentPath, file.name]);
                                                            } else {
                                                                handlePreview(file);
                                                            }
                                                        }}
                                                    >
                                                        <div className="p-1.5 bg-primary-50 dark:bg-primary-900/30 rounded flex-shrink-0">
                                                            {getSmallIcon(file.type)}
                                                        </div>
                                                        <div className="flex-1 min-w-0">
                                                            <p className="text-sm font-medium text-gray-900 dark:text-white truncate">{file.name}</p>
                                                            <p className="text-xs text-gray-500 dark:text-gray-400">{file.size}</p>
                                                        </div>
                                                        <Star className="w-3.5 h-3.5 text-yellow-400 fill-current flex-shrink-0" />
                                                    </div>
                                                ))}
                                            </div>
                                        </div>
                                    )}
                                </div>
                            )}
                        </div>
                        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                            {visibleStarred.map(file => (
                                <div 
                                    key={`quick-${file.id}`} 
                                    className="bg-white dark:bg-gray-800 p-3 rounded-lg border border-gray-200 dark:border-gray-700 shadow-sm hover:shadow-md transition-shadow cursor-pointer flex items-center space-x-3" 
                                    onClick={() => {
                                        if (file.type === 'folder') {
                                            setCurrentPath([...currentPath, file.name]);
                                        } else {
                                            handlePreview(file);
                                        }
                                    }}
                                >
                                    <div className="p-2 bg-primary-50 dark:bg-primary-900/30 rounded-lg flex-shrink-0">
                                        {getSmallIcon(file.type)}
                                    </div>
                                    <div className="flex-1 min-w-0">
                                        <p className="text-sm font-medium text-gray-900 dark:text-white truncate">{file.name}</p>
                                        <p className="text-xs text-gray-500 dark:text-gray-400">{file.size}</p>
                                    </div>
                                    <Star className="w-4 h-4 text-yellow-400 fill-current flex-shrink-0" />
                                </div>
                            ))}
                        </div>
                    </div>
                );
            })()}

            <UploadProgressModal
                isOpen={isUploadModalOpen}
                onClose={() => setIsUploadModalOpen(false)}
                files={uploadFilesList}
            />

            {previewFile && (
                <FilePreviewModal
                    isOpen={!!previewFile}
                    onClose={() => setPreviewFile(null)}
                    file={previewFile}
                />
            )}

            <RenameModal
                isOpen={isRenameOpen}
                onClose={() => setIsRenameOpen(false)}
                onRename={handleRename}
                currentName={fileToRename?.name || ''}
            />

            <NewFolderModal
                isOpen={isNewFolderOpen}
                onClose={() => setIsNewFolderOpen(false)}
                onCreate={handleCreateFolder}
            />

            <FileActivityModal
                isOpen={isActivityModalOpen}
                onClose={() => {
                    setIsActivityModalOpen(false);
                    setActivityFile(null);
                }}
                fileId={activityFile?.id || ''}
                fileName={activityFile?.name || ''}
            />

            {/* File Properties Modal */}
            <FilePropertiesModal
                isOpen={isPropertiesModalOpen}
                onClose={() => {
                    setIsPropertiesModalOpen(false);
                    setPropertiesFile(null);
                }}
                file={propertiesFile}
            />

            {/* Share File Modal */}
            {shareFile && (
                <ShareFileModal
                    isOpen={isShareModalOpen}
                    onClose={() => {
                        setIsShareModalOpen(false);
                        setShareFile(null);
                    }}
                    file={shareFile}
                    companyId={companyId}
                    complianceMode={currentCompany?.compliance_mode}
                />
            )}

            {/* Lock File Modal */}
            <LockFileModal
                isOpen={isLockModalOpen}
                onClose={() => {
                    setIsLockModalOpen(false);
                    setLockingFile(null);
                }}
                onLock={handleLockFile}
                fileName={lockingFile?.name || ''}
                isLocking={isLocking}
            />

            {/* Unlock File Modal */}
            <UnlockFileModal
                isOpen={isUnlockModalOpen}
                onClose={() => {
                    setIsUnlockModalOpen(false);
                    setLockingFile(null);
                }}
                onUnlock={handleUnlockFile}
                fileName={lockingFile?.name || ''}
                isUnlocking={isLocking}
                requiresPassword={lockingFile?.has_lock_password || false}
                requiredRole={lockingFile?.lock_requires_role}
            />

            {/* Move File Modal */}
            <MoveFileModal
                isOpen={isMoveModalOpen}
                onClose={() => {
                    setIsMoveModalOpen(false);
                    setMovingFile(null);
                }}
                onMove={handleMoveFile}
                fileName={movingFile?.name || ''}
                isMoving={isMoving}
                currentPath={currentPath.length > 1 ? currentPath.slice(1).join('/') : null}
                currentVisibility={fileViewMode}
                canCrossDepartment={user?.role === 'SuperAdmin' || user?.role === 'Admin'}
            />

            {/* Bulk Move Modal */}
            <MoveFileModal
                isOpen={isBulkMoveModalOpen}
                onClose={() => {
                    setIsBulkMoveModalOpen(false);
                }}
                onMove={handleBulkMove}
                fileName=""
                fileCount={selectedFiles.size}
                isMoving={isBulkMoving}
                currentPath={currentPath.length > 1 ? currentPath.slice(1).join('/') : null}
                currentVisibility={fileViewMode}
                canCrossDepartment={user?.role === 'SuperAdmin' || user?.role === 'Admin'}
            />

            <div
                className={clsx(
                    "bg-white dark:bg-gray-800 border rounded-lg shadow-sm flex-1 flex flex-col transition-colors mt-4",
                    isDragging ? "border-primary-500 bg-primary-50 dark:bg-primary-900/20 border-2 border-dashed" : "border-gray-200 dark:border-gray-700"
                )}
                onDragEnter={handleDrag}
                onDragLeave={handleDrag}
                onDragOver={handleDrag}
                onDrop={handleDrop}
            >
                {/* Toolbar */}
                <div className="px-4 py-3 border-b border-gray-200 dark:border-gray-700 flex flex-col sm:flex-row sm:items-center justify-between bg-gray-50 dark:bg-gray-900/50 bg-opacity-50 gap-3">
                    {/* Breadcrumbs */}
                    <div className="flex items-center space-x-2 text-sm text-gray-600 overflow-x-auto pb-2 sm:pb-0 scrollbar-hide">
                        <Clock className="w-4 h-4 flex-shrink-0 text-gray-400" />
                        {currentPath.map((folder, index) => (
                            <div key={index} className="flex items-center flex-shrink-0">
                                {index > 0 && <span className="mx-1 text-gray-400">/</span>}
                                <span
                                    className={clsx(
                                        "hover:text-primary-600 dark:hover:text-primary-400 cursor-pointer px-1 py-0.5 rounded transition-colors", 
                                        index === currentPath.length - 1 && "font-semibold text-gray-900 dark:text-white",
                                        index === 0 && dropTargetId === 'home' && "bg-primary-100 dark:bg-primary-900/30 ring-2 ring-primary-400"
                                    )}
                                    onClick={() => {
                                        // Navigate to this path
                                        const newPath = currentPath.slice(0, index + 1);
                                        setCurrentPath(newPath);
                                    }}
                                    onDragOver={(e) => {
                                        if (index === 0 && draggedFile) {
                                            e.preventDefault();
                                            handleDragOver(e, 'home');
                                        }
                                    }}
                                    onDragLeave={handleDragLeave}
                                    onDrop={(e) => {
                                        if (index === 0 && draggedFile) {
                                            handleMoveFileDrop(e, null); // null = move to root
                                        }
                                    }}
                                >
                                    {index === 0 && <Home className="w-3 h-3 inline mr-1" />}
                                    {folder}
                                </span>
                            </div>
                        ))}
                    </div>

                    {/* Search & View Toggle */}
                    <div className="flex items-center space-x-3 w-full sm:w-auto">
                        <div className="relative flex-1 sm:flex-none group">
                            <Search className="w-4 h-4 absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 group-hover:text-primary-500 transition-colors" />
                            <input
                                type="text"
                                placeholder="Search files..."
                                value={searchQuery}
                                onChange={(e) => setSearchQuery(e.target.value)}
                                className="w-full sm:w-64 pl-9 pr-4 py-1.5 text-sm border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-1 focus:ring-primary-500 bg-white dark:bg-gray-700 text-gray-900 dark:text-white placeholder-gray-500 dark:placeholder-gray-400 transition-shadow"
                            />
                        </div>
                        <div className="border-l border-gray-300 dark:border-gray-600 h-6 hidden sm:block" />
                        <div className="flex space-x-1 bg-gray-100 dark:bg-gray-700 p-1 rounded-lg">
                            <button
                                onClick={() => setViewMode('grid')}
                                className={clsx("p-1.5 rounded-md transition-all", viewMode === 'grid' ? "bg-white dark:bg-gray-600 shadow-sm text-primary-600 dark:text-primary-400" : "text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200")}
                            >
                                <Grid className="w-4 h-4" />
                            </button>
                            <button
                                onClick={() => setViewMode('list')}
                                className={clsx("p-1.5 rounded-md transition-all", viewMode === 'list' ? "bg-white dark:bg-gray-600 shadow-sm text-primary-600 dark:text-primary-400" : "text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200")}
                            >
                                <List className="w-4 h-4" />
                            </button>
                        </div>
                    </div>
                </div>

                {/* File Area */}
                <div className="p-4 relative flex flex-col flex-1 min-h-[400px]">
                    {isDragging && !draggedFile && (
                        <div className="absolute inset-0 flex items-center justify-center bg-white dark:bg-gray-800 bg-opacity-90 dark:bg-opacity-90 z-50 backdrop-blur-sm">
                            <div className="text-center p-8 border-4 border-dashed border-primary-400 rounded-xl bg-primary-50 dark:bg-primary-900/30">
                                <Upload className="w-16 h-16 text-primary-500 mx-auto mb-4 animate-bounce" />
                                <p className="text-xl font-bold text-primary-700 dark:text-primary-300">Drop files to upload</p>
                            </div>
                        </div>
                    )}

                    {/* Empty State */}
                    {!isLoading && filteredFiles.length === 0 && !isDragging && (
                        <div className="flex flex-col items-center justify-center flex-1 py-16 text-center">
                            <div className="p-6 rounded-full bg-gray-100 dark:bg-gray-800 mb-6">
                                <Folder className="w-16 h-16 text-gray-400 dark:text-gray-500" />
                            </div>
                            <h3 className="text-xl font-semibold text-gray-900 dark:text-white mb-2">
                                {searchQuery ? 'No files found' : 'No files yet'}
                            </h3>
                            <p className="text-gray-500 dark:text-gray-400 mb-6 max-w-md">
                                {searchQuery 
                                    ? `No files match "${searchQuery}". Try a different search term.`
                                    : 'Get started by uploading your first file or creating a folder. You can also drag and drop files here.'}
                            </p>
                            {!searchQuery && (
                                <div className="flex gap-3">
                                    <button
                                        onClick={() => setIsNewFolderOpen(true)}
                                        className="flex items-center px-4 py-2 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-lg text-sm font-medium text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-700 shadow-sm"
                                    >
                                        <FolderPlus className="w-4 h-4 mr-2" />
                                        New Folder
                                    </button>
                                    <button
                                        onClick={() => fileInputRef.current?.click()}
                                        className="flex items-center px-4 py-2 bg-primary-600 rounded-lg text-sm font-medium text-white hover:bg-primary-700 shadow-sm"
                                    >
                                        <Upload className="w-4 h-4 mr-2" />
                                        Upload Files
                                    </button>
                                </div>
                            )}
                        </div>
                    )}

                    {paginatedFiles.length > 0 && (viewMode === 'grid' ? (
                        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 2xl:grid-cols-8 min-[1800px]:grid-cols-10 min-[2200px]:grid-cols-12 min-[2800px]:grid-cols-14 min-[3200px]:grid-cols-16 gap-4 justify-items-center content-start">
                            {paginatedFiles.map((file, index) => (
                                <div
                                    key={file.id}
                                    className={clsx(
                                        "group relative bg-white dark:bg-gray-800 border rounded-xl p-4 hover:shadow-lg transition-all cursor-pointer flex flex-col items-center text-center h-44 w-full max-w-[180px]",
                                        selectedFiles.has(file.id)
                                            ? "border-primary-400 dark:border-primary-500 ring-2 ring-primary-200 dark:ring-primary-800"
                                            : focusedFileIndex === (currentPage - 1) * itemsPerPage + index
                                                ? "border-primary-300 dark:border-primary-600 ring-2 ring-primary-100 dark:ring-primary-900/50"
                                                : "border-gray-200 dark:border-gray-700 hover:border-primary-300 dark:hover:border-primary-500"
                                    )}
                                    draggable={!isSelectionMode}
                                    onDragStart={(e) => !isSelectionMode && handleFileDragStart(e, file)}
                                    onDragOver={(e) => file.type === 'folder' && handleFolderDragOver(e, file)}
                                    onDragLeave={handleFolderDragLeave}
                                    onDrop={(e) => file.type === 'folder' && handleFolderDrop(e, file)}
                                    onClick={(e) => {
                                        if (isSelectionMode) {
                                            e.stopPropagation();
                                            toggleFileSelection(file.id);
                                        }
                                    }}
                                >
                                    {/* Selection Checkbox */}
                                    {isSelectionMode && (
                                        <div 
                                            className="absolute top-2 left-2 z-10"
                                            onClick={(e) => { e.stopPropagation(); toggleFileSelection(file.id); }}
                                        >
                                            {selectedFiles.has(file.id) ? (
                                                <CheckSquare className="w-5 h-5 text-primary-600" />
                                            ) : (
                                                <Square className="w-5 h-5 text-gray-400 hover:text-primary-500" />
                                            )}
                                        </div>
                                    )}
                                    <div
                                        className="flex-1 flex items-center justify-center w-full mb-3"
                                        onClick={(e) => {
                                            if (isSelectionMode) return;
                                            if (file.type === 'folder') {
                                                setCurrentPath([...currentPath, file.name]);
                                            } else {
                                                handlePreview(file);
                                            }
                                        }}
                                    >
                                        {getIcon(file.type)}
                                    </div>
                                    <div className="w-full">
                                        <p className="text-sm font-medium text-gray-900 dark:text-white truncate w-full" title={file.name}>{file.name}</p>
                                        <div className="flex items-center justify-between mt-1">
                                            <p className="text-xs text-gray-500 dark:text-gray-400">{file.size}</p>
                                            {/* Owner avatar or company icon with styled hover tooltip */}
                                            <div className="relative group/avatar">
                                                {file.type === 'folder' && file.is_company_folder ? (
                                                    <div className="h-10 w-10 rounded-full bg-gray-200 dark:bg-gray-600 flex items-center justify-center ring-2 ring-white dark:ring-gray-800 shadow-sm">
                                                        <Building2 className="w-5 h-5 text-gray-600 dark:text-gray-300" />
                                                    </div>
                                                ) : (
                                                    <Avatar 
                                                        src={file.owner_avatar} 
                                                        name={file.owner || 'Unknown'} 
                                                        size="md"
                                                        className="ring-2 ring-white dark:ring-gray-800 shadow-sm hover:ring-primary-300 dark:hover:ring-primary-600 transition-all cursor-default"
                                                    />
                                                )}
                                                {/* Styled tooltip */}
                                                <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 px-3 py-1.5 bg-gray-900 dark:bg-gray-700 text-white text-xs rounded-lg opacity-0 group-hover/avatar:opacity-100 transition-opacity pointer-events-none whitespace-nowrap shadow-lg z-10">
                                                    <div className="font-medium">{file.type === 'folder' && file.is_company_folder ? 'Company Folder' : (file.owner || 'Unknown')}</div>
                                                    <div className="text-gray-400 text-[10px]">{file.type === 'folder' && file.is_company_folder ? 'Shared' : 'Owner'}</div>
                                                    {/* Tooltip arrow */}
                                                    <div className="absolute top-full left-1/2 -translate-x-1/2 border-4 border-transparent border-t-gray-900 dark:border-t-gray-700"></div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    <div className="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity flex space-x-1">
                                        {file.visibility === 'private' && <span title="Private - only visible to you"><EyeOff className="w-4 h-4 text-purple-500" /></span>}
                                        {file.is_locked && <span title="Locked"><Lock className="w-4 h-4 text-orange-500" /></span>}
                                        {file.is_starred && <Star className="w-4 h-4 text-yellow-400 fill-current" />}
                                        <button
                                            ref={(el) => { if (el) menuButtonRefs.current.set(`grid-${file.id}`, el); }}
                                            className="p-1 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-full bg-white dark:bg-gray-800 shadow-sm border border-gray-100 dark:border-gray-700"
                                            onClick={(e) => { e.stopPropagation(); setActiveMenu(activeMenu === file.id ? null : file.id); }}
                                        >
                                            <MoreVertical className="w-4 h-4 text-gray-500" />
                                        </button>
                                        {activeMenu === file.id && (
                                            <FileActionMenu
                                                file={file}
                                                companyId={companyId || ''}
                                                complianceMode={currentCompany?.compliance_mode}
                                                canLockFiles={canLockFiles}
                                                canViewActivity={canViewActivity}
                                                canDelete={canDeleteFile(file)}
                                                canShare={canShareFile(file)}
                                                currentUserId={user?.id}
                                                onPreview={handlePreview}
                                                onShare={handleShare}
                                                onDownload={handleDownload}
                                                onStar={toggleStar}
                                                onRename={(f) => { setFileToRename(f); setIsRenameOpen(true); }}
                                                onLock={handleLockToggle}
                                                onActivity={handleViewActivity}
                                                onMove={openMoveModal}
                                                onDelete={handleDelete}
                                                onProperties={handleViewProperties}
                                                onToggleCompanyFolder={handleToggleCompanyFolder}
                                                buttonRef={{ current: menuButtonRefs.current.get(`grid-${file.id}`) || null }}
                                            />
                                        )}
                                    </div>
                                </div>
                            ))}
                        </div>
                    ) : (
                        <div className="overflow-x-auto rounded-lg border border-gray-200 dark:border-gray-700">
                            <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                                <thead className="bg-gray-50 dark:bg-gray-900/50">
                                    <tr>
                                        {isSelectionMode && (
                                            <th className="px-4 py-3 w-10">
                                                <button
                                                    onClick={() => {
                                                        if (selectedFiles.size === paginatedFiles.length) {
                                                            setSelectedFiles(new Set());
                                                        } else {
                                                            selectAllFiles();
                                                        }
                                                    }}
                                                    className="text-gray-400 hover:text-primary-500"
                                                >
                                                    {selectedFiles.size === paginatedFiles.length && paginatedFiles.length > 0 ? (
                                                        <CheckSquare className="w-5 h-5 text-primary-600" />
                                                    ) : (
                                                        <Square className="w-5 h-5" />
                                                    )}
                                                </button>
                                            </th>
                                        )}
                                        <th
                                            className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider cursor-pointer hover:bg-gray-100 dark:hover:bg-gray-800 hover:text-gray-700 dark:hover:text-gray-200 transition-colors"
                                            onClick={() => handleSort('name')}
                                        >
                                            <div className="flex items-center">
                                                Name
                                                {sortBy === 'name' && (sortOrder === 'asc' ? <span className="ml-1">↑</span> : <span className="ml-1">↓</span>)}
                                            </div>
                                        </th>
                                        <th
                                            className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider hidden sm:table-cell cursor-pointer hover:bg-gray-100 dark:hover:bg-gray-800 hover:text-gray-700 dark:hover:text-gray-200 transition-colors"
                                            onClick={() => handleSort('size')}
                                        >
                                            <div className="flex items-center">
                                                Size
                                                {sortBy === 'size' && (sortOrder === 'asc' ? <span className="ml-1">↑</span> : <span className="ml-1">↓</span>)}
                                            </div>
                                        </th>
                                        <th
                                            className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider hidden md:table-cell cursor-pointer hover:bg-gray-100 dark:hover:bg-gray-800 hover:text-gray-700 dark:hover:text-gray-200 transition-colors"
                                            onClick={() => handleSort('modified')}
                                        >
                                            <div className="flex items-center">
                                                Modified
                                                {sortBy === 'modified' && (sortOrder === 'asc' ? <span className="ml-1">↑</span> : <span className="ml-1">↓</span>)}
                                            </div>
                                        </th>
                                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider hidden lg:table-cell">Owner</th>
                                        <th className="relative px-6 py-3"><span className="sr-only">Actions</span></th>
                                    </tr>
                                </thead>
                                <tbody className="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                                    {paginatedFiles.map((file, index) => (
                                        <tr
                                            key={file.id}
                                            className={clsx(
                                                "transition-colors cursor-pointer group",
                                                selectedFiles.has(file.id)
                                                    ? "bg-primary-50 dark:bg-primary-900/20"
                                                    : focusedFileIndex === (currentPage - 1) * itemsPerPage + index
                                                        ? "bg-primary-50/50 dark:bg-primary-900/10"
                                                        : "hover:bg-gray-50 dark:hover:bg-gray-700/50"
                                            )}
                                            draggable={!isSelectionMode}
                                            onDragStart={(e) => !isSelectionMode && handleFileDragStart(e, file)}
                                            onDragOver={(e) => file.type === 'folder' && handleFolderDragOver(e, file)}
                                            onDragLeave={handleFolderDragLeave}
                                            onDrop={(e) => file.type === 'folder' && handleFolderDrop(e, file)}
                                            onClick={() => {
                                                if (isSelectionMode) {
                                                    toggleFileSelection(file.id);
                                                }
                                            }}
                                        >
                                            {isSelectionMode && (
                                                <td className="px-4 py-4 w-10">
                                                    <button
                                                        onClick={(e) => { e.stopPropagation(); toggleFileSelection(file.id); }}
                                                        className="text-gray-400 hover:text-primary-500"
                                                    >
                                                        {selectedFiles.has(file.id) ? (
                                                            <CheckSquare className="w-5 h-5 text-primary-600" />
                                                        ) : (
                                                            <Square className="w-5 h-5" />
                                                        )}
                                                    </button>
                                                </td>
                                            )}
                                            <td className="px-6 py-4 whitespace-nowrap" onClick={(e) => {
                                                if (isSelectionMode) return;
                                                if (file.type === 'folder') {
                                                    setCurrentPath([...currentPath, file.name]);
                                                } else {
                                                    handlePreview(file);
                                                }
                                            }}>
                                                <div className="flex items-center">
                                                    <div className="flex-shrink-0 h-8 w-8 flex items-center justify-center">
                                                        {getIcon(file.type)}
                                                    </div>
                                                    <div className="ml-4">
                                                        <div className="text-sm font-medium text-gray-900 dark:text-white flex items-center">
                                                            {file.name}
                                                            {file.visibility === 'private' && <span title="Private"><EyeOff className="w-3.5 h-3.5 ml-2 text-purple-500" /></span>}
                                                            {file.is_locked && <span title="Locked"><Lock className="w-3.5 h-3.5 ml-1 text-orange-500" /></span>}
                                                        </div>
                                                        <div className="sm:hidden text-xs text-gray-500 dark:text-gray-400">{file.size} • {file.modified}</div>
                                                    </div>
                                                </div>
                                            </td>
                                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400 hidden sm:table-cell">
                                                {file.size}
                                            </td>
                                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400 hidden md:table-cell">
                                                {file.modified}
                                            </td>
                                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400 hidden lg:table-cell">
                                                <div className="flex items-center" title={file.type === 'folder' && file.is_company_folder ? 'Company Folder' : (file.owner || 'Unknown')}>
                                                    {file.type === 'folder' && file.is_company_folder ? (
                                                        <div className="h-6 w-6 rounded-full bg-gray-200 dark:bg-gray-600 flex items-center justify-center mr-2">
                                                            <Building2 className="w-3 h-3 text-gray-600 dark:text-gray-300" />
                                                        </div>
                                                    ) : (
                                                        <Avatar 
                                                            src={file.owner_avatar} 
                                                            name={file.owner || 'Unknown'} 
                                                            size="xs"
                                                            className="mr-2"
                                                        />
                                                    )}
                                                    <span>{file.type === 'folder' && file.is_company_folder ? 'Company' : (file.owner || 'Unknown')}</span>
                                                </div>
                                            </td>
                                            <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium relative">
                                                <div className="opacity-0 group-hover:opacity-100 transition-opacity">
                                                    <button
                                                        ref={(el) => { if (el) menuButtonRefs.current.set(`list-${file.id}`, el); }}
                                                        className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 p-1 rounded-full hover:bg-gray-100 dark:hover:bg-gray-700"
                                                        onClick={(e) => {
                                                            e.stopPropagation();
                                                            setActiveMenu(activeMenu === file.id ? null : file.id);
                                                        }}
                                                    >
                                                        <MoreVertical className="w-5 h-5" />
                                                    </button>
                                                </div>
                                                {activeMenu === file.id && (
                                                    <FileActionMenu
                                                        file={file}
                                                        companyId={companyId || ''}
                                                        complianceMode={currentCompany?.compliance_mode}
                                                        canLockFiles={canLockFiles}
                                                        canViewActivity={canViewActivity}
                                                        canDelete={canDeleteFile(file)}
                                                        canShare={canShareFile(file)}
                                                        currentUserId={user?.id}
                                                        onPreview={handlePreview}
                                                        onShare={handleShare}
                                                        onDownload={handleDownload}
                                                        onStar={toggleStar}
                                                        onRename={(f) => { setFileToRename(f); setIsRenameOpen(true); }}
                                                        onLock={handleLockToggle}
                                                        onActivity={handleViewActivity}
                                                        onMove={openMoveModal}
                                                        onDelete={handleDelete}
                                                        onProperties={handleViewProperties}
                                                        onToggleCompanyFolder={handleToggleCompanyFolder}
                                                        buttonRef={{ current: menuButtonRefs.current.get(`list-${file.id}`) || null }}
                                                    />
                                                )}
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                    ))}

                    {/* Pagination Controls */}
                    {totalPages > 1 && (
                        <div className="flex items-center justify-between mt-6 pt-4 border-t border-gray-200 dark:border-gray-700">
                            <p className="text-sm text-gray-500 dark:text-gray-400">
                                Showing {((currentPage - 1) * itemsPerPage) + 1} - {Math.min(currentPage * itemsPerPage, filteredFiles.length)} of {filteredFiles.length} items
                            </p>
                            <div className="flex items-center space-x-2">
                                <button
                                    onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
                                    disabled={currentPage === 1}
                                    className={clsx(
                                        "flex items-center px-3 py-1.5 text-sm font-medium rounded-lg border transition-colors",
                                        currentPage === 1
                                            ? "text-gray-400 dark:text-gray-600 border-gray-200 dark:border-gray-700 cursor-not-allowed"
                                            : "text-gray-700 dark:text-gray-200 border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700"
                                    )}
                                >
                                    <ChevronLeft className="w-4 h-4 mr-1" />
                                    Previous
                                </button>
                                <div className="flex items-center space-x-1">
                                    {Array.from({ length: totalPages }, (_, i) => i + 1)
                                        .filter(page => {
                                            // Show first, last, current, and pages around current
                                            return page === 1 || page === totalPages || Math.abs(page - currentPage) <= 1;
                                        })
                                        .map((page, index, array) => (
                                            <React.Fragment key={page}>
                                                {index > 0 && array[index - 1] !== page - 1 && (
                                                    <span className="px-2 text-gray-400">...</span>
                                                )}
                                                <button
                                                    onClick={() => setCurrentPage(page)}
                                                    className={clsx(
                                                        "w-8 h-8 text-sm font-medium rounded-lg transition-colors",
                                                        currentPage === page
                                                            ? "bg-primary-600 text-white"
                                                            : "text-gray-700 dark:text-gray-200 hover:bg-gray-100 dark:hover:bg-gray-700"
                                                    )}
                                                >
                                                    {page}
                                                </button>
                                            </React.Fragment>
                                        ))}
                                </div>
                                <button
                                    onClick={() => setCurrentPage(prev => Math.min(totalPages, prev + 1))}
                                    disabled={currentPage === totalPages}
                                    className={clsx(
                                        "flex items-center px-3 py-1.5 text-sm font-medium rounded-lg border transition-colors",
                                        currentPage === totalPages
                                            ? "text-gray-400 dark:text-gray-600 border-gray-200 dark:border-gray-700 cursor-not-allowed"
                                            : "text-gray-700 dark:text-gray-200 border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700"
                                    )}
                                >
                                    Next
                                    <ChevronRight className="w-4 h-4 ml-1" />
                                </button>
                            </div>
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
}
