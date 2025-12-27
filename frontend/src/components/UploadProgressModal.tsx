import React from 'react';
import { X, FileText, CheckCircle, AlertCircle, Loader2 } from 'lucide-react';
import clsx from 'clsx';

export interface UploadFile {
    file: File;
    progress: number;
    status: 'pending' | 'uploading' | 'completed' | 'error';
    error?: string;
}

interface UploadProgressModalProps {
    isOpen: boolean;
    onClose: () => void;
    files: UploadFile[];
}

export function UploadProgressModal({ isOpen, onClose, files }: UploadProgressModalProps) {
    if (!isOpen) return null;

    const totalProgress = files.reduce((acc, f) => acc + f.progress, 0) / files.length;
    const isAllCompleted = files.every(f => f.status === 'completed');
    const hasErrors = files.some(f => f.status === 'error');

    return (
        <div className="fixed inset-0 z-50 overflow-y-auto">
            <div className="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
                <div className="fixed inset-0 transition-opacity" aria-hidden="true">
                    <div className="absolute inset-0 bg-gray-500 opacity-75"></div>
                </div>

                <span className="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">&#8203;</span>

                <div className="inline-block align-bottom bg-white dark:bg-gray-800 rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg w-full">
                    <div className="bg-white dark:bg-gray-800 px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
                        <div className="sm:flex sm:items-start">
                            <div className="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left w-full">
                                <h3 className="text-lg leading-6 font-medium text-gray-900 dark:text-white flex justify-between items-center">
                                    <span>Uploading {files.length} {files.length === 1 ? 'file' : 'files'}</span>
                                    {isAllCompleted && <span className="text-green-600 text-sm font-normal">Completed</span>}
                                </h3>

                                {/* Overall Progress */}
                                <div className="mt-4 relative pt-1">
                                    <div className="overflow-hidden h-2 mb-4 text-xs flex rounded bg-gray-200 dark:bg-gray-700">
                                        <div style={{ width: `${totalProgress}%` }} className={clsx("shadow-none flex flex-col text-center whitespace-nowrap text-white justify-center transition-all duration-500", hasErrors ? "bg-red-500" : "bg-primary-600")}></div>
                                    </div>
                                </div>

                                {/* File List */}
                                <div className="mt-4 max-h-60 overflow-y-auto space-y-3">
                                    {files.map((f, idx) => (
                                        <div key={idx} className="flex items-center justify-between text-sm">
                                            <div className="flex items-center overflow-hidden">
                                                <FileText className="h-4 w-4 text-gray-400 mr-2 flex-shrink-0" />
                                                <span className="truncate max-w-xs text-gray-700 dark:text-gray-300">{f.file.name}</span>
                                            </div>
                                            <div className="flex items-center ml-2">
                                                {f.status === 'uploading' && <Loader2 className="h-4 w-4 text-primary-500 animate-spin" />}
                                                {f.status === 'completed' && <CheckCircle className="h-4 w-4 text-green-500" />}
                                                {f.status === 'error' && <AlertCircle className="h-4 w-4 text-red-500" />}
                                                {f.status === 'pending' && <span className="text-gray-400 text-xs">Waiting...</span>}
                                            </div>
                                        </div>
                                    ))}
                                </div>
                            </div>
                        </div>
                    </div>
                    <div className="bg-gray-50 dark:bg-gray-900/50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
                        <button
                            type="button"
                            onClick={onClose}
                            className="w-full inline-flex justify-center rounded-md border border-gray-300 dark:border-gray-600 shadow-sm px-4 py-2 bg-white dark:bg-gray-700 text-base font-medium text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 sm:ml-3 sm:w-auto sm:text-sm"
                        >
                            {isAllCompleted ? 'Close' : 'Cancel'}
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
}
