import React, { useEffect, useState } from 'react';
import { createPortal } from 'react-dom';
import {
    Eye, Download, Trash2, Star, Edit2, Share2,
    Lock, Unlock, History, Move, Info, Building2
} from 'lucide-react';
import clsx from 'clsx';

export interface FileItem {
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

interface FileActionMenuProps {
    file: FileItem;
    companyId: string;
    complianceMode?: string;
    canLockFiles: boolean;
    canViewActivity: boolean;
    canDelete: boolean;
    canShare: boolean;  // Only owner, manager, or admin can share
    currentUserId?: string;  // Current user's ID for ownership checks
    onPreview: (file: FileItem) => void;
    onShare: (file: FileItem) => void;
    onDownload: (file: FileItem) => void;
    onStar: (file: FileItem) => void;
    onRename: (file: FileItem) => void;
    onLock: (file: FileItem) => void;
    onActivity: (file: FileItem) => void;
    onMove: (file: FileItem) => void;
    onDelete: (file: FileItem) => void;
    onProperties: (file: FileItem) => void;
    onToggleCompanyFolder?: (file: FileItem) => void;
    buttonRef?: { current: HTMLButtonElement | null };
}

const menuItemClass = "flex items-center w-full px-4 py-2 text-sm text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-700";
const dividerClass = "border-t border-gray-100 dark:border-gray-700 my-1";

export function FileActionMenu({
    file,
    companyId,
    complianceMode,
    canLockFiles,
    canViewActivity,
    canDelete,
    canShare,
    currentUserId,
    onPreview,
    onShare,
    onDownload,
    onStar,
    onRename,
    onLock,
    onActivity,
    onMove,
    onDelete,
    onProperties,
    onToggleCompanyFolder,
    buttonRef,
}: FileActionMenuProps) {
    const isFile = file.type !== 'folder';
    // Case-insensitive check for compliance mode (backend may return "HIPAA", "Hipaa", etc.)
    const isComplianceMode = ['hipaa', 'soc2', 'gdpr'].includes(complianceMode?.toLowerCase() || '');
    
    // Check if user can access locked file (they're the locker, owner, or admin - admin checked via canShare/canLockFiles)
    const isOwner = currentUserId && file.owner_id === currentUserId;
    const isLocker = currentUserId && file.locked_by === currentUserId;
    const canAccessLockedFile = !file.is_locked || isLocker || isOwner || canLockFiles;

    const [position, setPosition] = useState({ top: 0, right: 0 });

    useEffect(() => {
        if (buttonRef?.current) {
            const rect = buttonRef.current.getBoundingClientRect();
            // Calculate position - menu appears below button, aligned to right edge
            const menuWidth = 192; // w-48 = 12rem = 192px
            const menuHeight = 350; // approximate max height
            
            let top = rect.bottom + 8;
            let right = window.innerWidth - rect.right;
            
            // Check if menu would go off-screen bottom
            if (top + menuHeight > window.innerHeight) {
                // Position above the button instead
                top = rect.top - menuHeight - 8;
                if (top < 0) top = 8; // Minimum top padding
            }
            
            // Check if menu would go off-screen right
            if (right < 8) right = 8;
            
            setPosition({ top, right });
        }
    }, [buttonRef]);

    const menuContent = (
        <div 
            className="fixed w-48 bg-white dark:bg-gray-800 rounded-md shadow-xl z-[100] border border-gray-100 dark:border-gray-700 ring-1 ring-black ring-opacity-5 text-left"
            style={{ top: position.top, right: position.right }}
        >
            <div className="py-1">
                {/* Preview - Files only, requires access to locked files */}
                {isFile && canAccessLockedFile && (
                    <button className={menuItemClass} onClick={() => onPreview(file)}>
                        <Eye className="w-4 h-4 mr-2 text-gray-400" /> Preview
                    </button>
                )}

                {/* Share - Only if user can share AND can access locked file */}
                {canShare && canAccessLockedFile && (
                    <button className={menuItemClass} onClick={() => onShare(file)}>
                        <Share2 className="w-4 h-4 mr-2 text-gray-400" /> Share
                    </button>
                )}

                {/* Star - always visible */}
                <button className={menuItemClass} onClick={() => onStar(file)}>
                    <Star className={clsx("w-4 h-4 mr-2", file.is_starred ? "text-yellow-400 fill-current" : "text-gray-400")} />
                    {file.is_starred ? "Unstar" : "Star"}
                </button>

                {/* Download - requires access to locked files */}
                {canAccessLockedFile && (
                    <button className={menuItemClass} onClick={() => onDownload(file)}>
                        <Download className="w-4 h-4 mr-2 text-gray-400" /> Download
                    </button>
                )}

                {/* Rename - requires access to locked files */}
                {canAccessLockedFile && !file.is_locked && (
                    <button className={menuItemClass} onClick={() => onRename(file)}>
                        <Edit2 className="w-4 h-4 mr-2 text-gray-400" /> Rename
                    </button>
                )}

                <div className={dividerClass}></div>

                {/* Lock/Unlock - Only for Manager, Admin, SuperAdmin who can access the file */}
                {canLockFiles && canAccessLockedFile && (
                    <button className={menuItemClass} onClick={() => onLock(file)}>
                        {file.is_locked ? (
                            <>
                                <Unlock className="w-4 h-4 mr-2 text-green-500" /> Unlock
                            </>
                        ) : (
                            <>
                                <Lock className="w-4 h-4 mr-2 text-orange-500" /> Lock
                            </>
                        )}
                    </button>
                )}

                {/* Recent Activity - Only for Admin, SuperAdmin */}
                {canViewActivity && (
                    <button className={menuItemClass} onClick={() => onActivity(file)}>
                        <History className="w-4 h-4 mr-2 text-gray-400" /> Recent Activity
                    </button>
                )}

                {/* Move To - Only if not locked and user can access */}
                {!file.is_locked && canAccessLockedFile && (
                    <button className={menuItemClass} onClick={() => onMove(file)}>
                        <Move className="w-4 h-4 mr-2 text-gray-400" /> Move To...
                    </button>
                )}

                {/* Toggle Company Folder - Folders only, Admin+ */}
                {file.type === 'folder' && onToggleCompanyFolder && canLockFiles && (
                    <button className={`${menuItemClass} whitespace-nowrap`} onClick={() => onToggleCompanyFolder(file)}>
                        <Building2 className={clsx("w-4 h-4 mr-2 flex-shrink-0", file.is_company_folder ? "text-blue-500" : "text-gray-400")} />
                        {file.is_company_folder ? "Unset Company" : "Set as Company"}
                    </button>
                )}

                {/* Properties */}
                <button className={menuItemClass} onClick={() => onProperties(file)}>
                    <Info className="w-4 h-4 mr-2 text-gray-400" /> Properties
                </button>

                <div className={dividerClass}></div>

                {/* Delete - Only owner or Admin/SuperAdmin, not locked or user can unlock */}
                {canDelete && (!file.is_locked || canAccessLockedFile) && (
                    <button
                        className="flex items-center w-full px-4 py-2 text-sm text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20"
                        onClick={() => onDelete(file)}
                    >
                        <Trash2 className="w-4 h-4 mr-2" /> Delete
                    </button>
                )}

                {/* Locked file message - shown to users who can't access */}
                {file.is_locked && !canAccessLockedFile && (
                    <div className="px-4 py-2 text-xs text-red-400 dark:text-red-500 italic">
                        File is locked - access denied
                    </div>
                )}
            </div>
        </div>
    );

    // If buttonRef is provided, use portal for fixed positioning
    // Otherwise fall back to absolute positioning (backwards compatible)
    if (buttonRef) {
        return createPortal(menuContent, document.body);
    }

    // Fallback to original absolute positioning
    return (
        <div className="absolute right-0 mt-2 w-48 bg-white dark:bg-gray-800 rounded-md shadow-xl z-20 border border-gray-100 dark:border-gray-700 ring-1 ring-black ring-opacity-5 text-left">
            <div className="py-1">
                {/* Preview - Files only, requires access to locked files */}
                {isFile && canAccessLockedFile && (
                    <button className={menuItemClass} onClick={() => onPreview(file)}>
                        <Eye className="w-4 h-4 mr-2 text-gray-400" /> Preview
                    </button>
                )}

                {/* Share - Only if user can share AND can access locked file */}
                {canShare && canAccessLockedFile && (
                    <button className={menuItemClass} onClick={() => onShare(file)}>
                        <Share2 className="w-4 h-4 mr-2 text-gray-400" /> Share
                    </button>
                )}

                {/* Star - always visible */}
                <button className={menuItemClass} onClick={() => onStar(file)}>
                    <Star className={clsx("w-4 h-4 mr-2", file.is_starred ? "text-yellow-400 fill-current" : "text-gray-400")} />
                    {file.is_starred ? "Unstar" : "Star"}
                </button>

                {/* Download - requires access to locked files */}
                {canAccessLockedFile && (
                    <button className={menuItemClass} onClick={() => onDownload(file)}>
                        <Download className="w-4 h-4 mr-2 text-gray-400" /> Download
                    </button>
                )}

                {/* Rename - requires access to locked files */}
                {canAccessLockedFile && !file.is_locked && (
                    <button className={menuItemClass} onClick={() => onRename(file)}>
                        <Edit2 className="w-4 h-4 mr-2 text-gray-400" /> Rename
                    </button>
                )}

                <div className={dividerClass}></div>

                {/* Lock/Unlock - Only for Manager, Admin, SuperAdmin who can access the file */}
                {canLockFiles && canAccessLockedFile && (
                    <button className={menuItemClass} onClick={() => onLock(file)}>
                        {file.is_locked ? (
                            <>
                                <Unlock className="w-4 h-4 mr-2 text-green-500" /> Unlock
                            </>
                        ) : (
                            <>
                                <Lock className="w-4 h-4 mr-2 text-orange-500" /> Lock
                            </>
                        )}
                    </button>
                )}

                {/* Recent Activity - Only for Admin, SuperAdmin */}
                {canViewActivity && (
                    <button className={menuItemClass} onClick={() => onActivity(file)}>
                        <History className="w-4 h-4 mr-2 text-gray-400" /> Recent Activity
                    </button>
                )}

                {/* Move To - Only if not locked and user can access */}
                {!file.is_locked && canAccessLockedFile && (
                    <button className={menuItemClass} onClick={() => onMove(file)}>
                        <Move className="w-4 h-4 mr-2 text-gray-400" /> Move To...
                    </button>
                )}

                {/* Toggle Company Folder - Folders only, Admin+ */}
                {file.type === 'folder' && onToggleCompanyFolder && canLockFiles && (
                    <button className={menuItemClass} onClick={() => onToggleCompanyFolder(file)}>
                        <Building2 className={clsx("w-4 h-4 mr-2", file.is_company_folder ? "text-blue-500" : "text-gray-400")} />
                        {file.is_company_folder ? "Remove Company Folder" : "Mark as Company Folder"}
                    </button>
                )}

                {/* Properties */}
                <button className={menuItemClass} onClick={() => onProperties(file)}>
                    <Info className="w-4 h-4 mr-2 text-gray-400" /> Properties
                </button>

                <div className={dividerClass}></div>

                {/* Delete - Only owner or Admin/SuperAdmin, not locked or user can unlock */}
                {canDelete && (!file.is_locked || canAccessLockedFile) && (
                    <button
                        className="flex items-center w-full px-4 py-2 text-sm text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20"
                        onClick={() => onDelete(file)}
                    >
                        <Trash2 className="w-4 h-4 mr-2" /> Delete
                    </button>
                )}

                {/* Locked file message - shown to users who can't access */}
                {file.is_locked && !canAccessLockedFile && (
                    <div className="px-4 py-2 text-xs text-red-400 dark:text-red-500 italic">
                        File is locked - access denied
                    </div>
                )}
            </div>
        </div>
    );
}
