import { useState } from 'react';
import { X, Link2, Copy, Check, Globe, Lock, Calendar, AlertCircle, Loader2, Folder, FileText } from 'lucide-react';
import clsx from 'clsx';
import { useAuthFetch } from '../context/AuthContext';

interface ShareFileModalProps {
    isOpen: boolean;
    onClose: () => void;
    file: {
        id: string;
        name: string;
        type?: 'folder' | 'image' | 'document' | 'video' | 'audio' | string;
    };
    companyId: string;
    complianceMode?: string;
}

export function ShareFileModal({ isOpen, onClose, file, companyId, complianceMode }: ShareFileModalProps) {
    const isFolder = file.type === 'folder';
    const authFetch = useAuthFetch();
    const [isPublic, setIsPublic] = useState(false);
    const [hasExpiration, setHasExpiration] = useState(false);
    const [expirationDays, setExpirationDays] = useState(7);
    const [isCreating, setIsCreating] = useState(false);
    const [shareLink, setShareLink] = useState<string | null>(null);
    const [copied, setCopied] = useState(false);
    const [error, setError] = useState<string | null>(null);

    // Check if public sharing is blocked by compliance mode
    const isComplianceMode = complianceMode && ['HIPAA', 'SOC2', 'GDPR'].includes(complianceMode);

    const handleCreateShare = async () => {
        setIsCreating(true);
        setError(null);

        try {
            const response = await authFetch(`/api/files/${companyId}/${file.id}/share`, {
                method: 'POST',
                body: JSON.stringify({
                    is_public: isPublic,
                    expires_in_days: hasExpiration ? expirationDays : null,
                }),
            });

            if (response.ok) {
                const data = await response.json();
                setShareLink(data.link);
            } else if (response.status === 403) {
                setError('Public sharing is not allowed in your compliance mode.');
            } else {
                setError('Failed to create share link. Please try again.');
            }
        } catch (err) {
            setError('An error occurred. Please try again.');
        } finally {
            setIsCreating(false);
        }
    };

    const handleCopy = async () => {
        if (shareLink) {
            await navigator.clipboard.writeText(shareLink);
            setCopied(true);
            setTimeout(() => setCopied(false), 2000);
        }
    };

    const handleClose = () => {
        setShareLink(null);
        setIsPublic(false);
        setHasExpiration(false);
        setExpirationDays(7);
        setError(null);
        setCopied(false);
        onClose();
    };

    if (!isOpen) return null;

    return (
        <div className="fixed inset-0 z-50 overflow-y-auto">
            <div className="flex min-h-full items-center justify-center p-4">
                {/* Backdrop */}
                <div className="fixed inset-0 bg-black/50 transition-opacity" onClick={handleClose} />

                {/* Modal */}
                <div className="relative bg-white dark:bg-gray-800 rounded-xl shadow-2xl w-full max-w-md transform transition-all">
                    {/* Header */}
                    <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200 dark:border-gray-700">
                        <div className="flex items-center gap-3">
                            <div className="p-2 bg-primary-100 dark:bg-primary-900/30 rounded-lg">
                                {isFolder ? (
                                    <Folder className="w-5 h-5 text-primary-600 dark:text-primary-400" />
                                ) : (
                                    <Link2 className="w-5 h-5 text-primary-600 dark:text-primary-400" />
                                )}
                            </div>
                            <div>
                                <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
                                    Share {isFolder ? 'Folder' : 'File'}
                                </h3>
                                <p className="text-sm text-gray-500 dark:text-gray-400 truncate max-w-[250px]">{file.name}</p>
                            </div>
                        </div>
                        <button
                            onClick={handleClose}
                            className="p-2 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
                        >
                            <X className="w-5 h-5" />
                        </button>
                    </div>

                    {/* Content */}
                    <div className="p-6">
                        {shareLink ? (
                            // Success state - show the link
                            <div className="space-y-4">
                                <div className="p-4 bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg">
                                    <div className="flex items-center gap-2 text-green-700 dark:text-green-300 text-sm font-medium mb-2">
                                        <Check className="w-4 h-4" />
                                        Share link created!
                                    </div>
                                    <p className="text-xs text-green-600 dark:text-green-400">
                                        {isPublic 
                                            ? `Anyone with this link can download the ${isFolder ? 'folder as a zip file' : 'file'}.` 
                                            : `Only logged-in users from your organization can access this ${isFolder ? 'folder' : 'file'}.`}
                                    </p>
                                    {isFolder && (
                                        <p className="text-xs text-green-600 dark:text-green-400 mt-1">
                                            📁 Folder contents will be automatically zipped when downloaded.
                                        </p>
                                    )}
                                </div>

                                <div className="flex gap-2">
                                    <input
                                        type="text"
                                        value={shareLink}
                                        readOnly
                                        className="flex-1 px-3 py-2 text-sm bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-lg text-gray-700 dark:text-gray-300"
                                    />
                                    <button
                                        onClick={handleCopy}
                                        className={clsx(
                                            "px-4 py-2 rounded-lg font-medium text-sm transition-all flex items-center gap-2",
                                            copied
                                                ? "bg-green-600 text-white"
                                                : "bg-primary-600 text-white hover:bg-primary-700"
                                        )}
                                    >
                                        {copied ? <Check className="w-4 h-4" /> : <Copy className="w-4 h-4" />}
                                        {copied ? 'Copied!' : 'Copy'}
                                    </button>
                                </div>

                                <button
                                    onClick={handleClose}
                                    className="w-full py-2 text-sm text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200 transition-colors"
                                >
                                    Done
                                </button>
                            </div>
                        ) : (
                            // Configuration state
                            <div className="space-y-5">
                                {/* Access Type */}
                                <div>
                                    <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-3">
                                        Who can access this link?
                                    </label>
                                    <div className="grid grid-cols-2 gap-3">
                                        <button
                                            onClick={() => setIsPublic(false)}
                                            disabled={isCreating}
                                            className={clsx(
                                                "flex flex-col items-center gap-2 p-4 rounded-lg border-2 transition-all",
                                                !isPublic
                                                    ? "border-primary-500 bg-primary-50 dark:bg-primary-900/20"
                                                    : "border-gray-200 dark:border-gray-700 hover:border-gray-300 dark:hover:border-gray-600"
                                            )}
                                        >
                                            <Lock className={clsx("w-6 h-6", !isPublic ? "text-primary-600 dark:text-primary-400" : "text-gray-400")} />
                                            <span className={clsx("text-sm font-medium", !isPublic ? "text-primary-700 dark:text-primary-300" : "text-gray-600 dark:text-gray-400")}>
                                                Organization Only
                                            </span>
                                            <span className="text-xs text-gray-500 dark:text-gray-500 text-center">
                                                Must be logged in
                                            </span>
                                        </button>

                                        <button
                                            onClick={() => !isComplianceMode && setIsPublic(true)}
                                            disabled={isCreating || !!isComplianceMode}
                                            className={clsx(
                                                "flex flex-col items-center gap-2 p-4 rounded-lg border-2 transition-all",
                                                isComplianceMode && "opacity-50 cursor-not-allowed",
                                                isPublic
                                                    ? "border-primary-500 bg-primary-50 dark:bg-primary-900/20"
                                                    : "border-gray-200 dark:border-gray-700 hover:border-gray-300 dark:hover:border-gray-600"
                                            )}
                                        >
                                            <Globe className={clsx("w-6 h-6", isPublic ? "text-primary-600 dark:text-primary-400" : "text-gray-400")} />
                                            <span className={clsx("text-sm font-medium", isPublic ? "text-primary-700 dark:text-primary-300" : "text-gray-600 dark:text-gray-400")}>
                                                Anyone with Link
                                            </span>
                                            <span className="text-xs text-gray-500 dark:text-gray-500 text-center">
                                                {isComplianceMode ? 'Blocked by compliance' : 'No login required'}
                                            </span>
                                        </button>
                                    </div>
                                </div>

                                {/* Expiration */}
                                <div>
                                    <div className="flex items-center justify-between mb-3">
                                        <label className="text-sm font-medium text-gray-700 dark:text-gray-300">
                                            Set expiration date?
                                        </label>
                                        <button
                                            onClick={() => setHasExpiration(!hasExpiration)}
                                            disabled={isCreating}
                                            className={clsx(
                                                "relative w-11 h-6 rounded-full transition-colors",
                                                hasExpiration ? "bg-primary-600" : "bg-gray-200 dark:bg-gray-700"
                                            )}
                                        >
                                            <span
                                                className={clsx(
                                                    "absolute top-1 left-1 w-4 h-4 bg-white rounded-full transition-transform",
                                                    hasExpiration && "translate-x-5"
                                                )}
                                            />
                                        </button>
                                    </div>

                                    {hasExpiration && (
                                        <div className="flex items-center gap-3 p-3 bg-gray-50 dark:bg-gray-900 rounded-lg">
                                            <Calendar className="w-5 h-5 text-gray-400" />
                                            <span className="text-sm text-gray-600 dark:text-gray-400">Expires in</span>
                                            <select
                                                value={expirationDays}
                                                onChange={(e) => setExpirationDays(Number(e.target.value))}
                                                disabled={isCreating}
                                                className="flex-1 px-3 py-1.5 text-sm bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                                            >
                                                <option value={1}>1 day</option>
                                                <option value={3}>3 days</option>
                                                <option value={7}>7 days</option>
                                                <option value={14}>14 days</option>
                                                <option value={30}>30 days</option>
                                                <option value={90}>90 days</option>
                                            </select>
                                        </div>
                                    )}
                                </div>

                                {/* Error */}
                                {error && (
                                    <div className="p-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg flex items-start gap-2">
                                        <AlertCircle className="w-4 h-4 text-red-500 mt-0.5" />
                                        <span className="text-sm text-red-700 dark:text-red-300">{error}</span>
                                    </div>
                                )}

                                {/* Actions */}
                                <div className="flex gap-3 pt-2">
                                    <button
                                        onClick={handleClose}
                                        disabled={isCreating}
                                        className="flex-1 px-4 py-2.5 text-sm font-medium text-gray-700 dark:text-gray-300 bg-gray-100 dark:bg-gray-700 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-600 transition-colors"
                                    >
                                        Cancel
                                    </button>
                                    <button
                                        onClick={handleCreateShare}
                                        disabled={isCreating}
                                        className="flex-1 px-4 py-2.5 text-sm font-medium text-white bg-primary-600 rounded-lg hover:bg-primary-700 transition-colors flex items-center justify-center gap-2 disabled:opacity-50"
                                    >
                                        {isCreating ? (
                                            <>
                                                <Loader2 className="w-4 h-4 animate-spin" />
                                                Creating...
                                            </>
                                        ) : (
                                            <>
                                                <Link2 className="w-4 h-4" />
                                                Create Link
                                            </>
                                        )}
                                    </button>
                                </div>
                            </div>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
}

