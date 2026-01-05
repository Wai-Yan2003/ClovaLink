import { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { Lock, Mail, AlertCircle, ShieldAlert } from 'lucide-react';

export function Login() {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [code, setCode] = useState('');
    const [show2FA, setShow2FA] = useState(false);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');
    const [isSuspended, setIsSuspended] = useState(false);
    const [rememberMe, setRememberMe] = useState(false);
    const { login } = useAuth();

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setLoading(true);
        setError('');
        setIsSuspended(false);

        try {
            const result = await login(email, password, code, rememberMe);
            
            // Check for suspended account or company
            if (result && (result.error === 'account_suspended' || result.error === 'company_suspended')) {
                setIsSuspended(true);
                setError(result.message || 'Access denied. Please contact your administrator.');
                setLoading(false);
                return;
            }
            
            if (result && result.require_2fa) {
                setShow2FA(true);
                setLoading(false);
                return;
            }
            // Navigation handled by AuthContext
        } catch (err: any) {
            console.error('Login error:', err);
            setError('Invalid email, password, or 2FA code. Please try again.');
            setLoading(false);
        }
    };

    return (
        <div className="min-h-screen bg-white flex flex-col justify-center py-12 sm:px-6 lg:px-8">
            <div className="sm:mx-auto sm:w-full sm:max-w-md">
                {/* Logo */}
                <div className="flex justify-center">
                    <img src="/logo.svg" alt="ClovaLink" className="h-48 w-auto" />
                </div>
                <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">
                    Sign in to your account
                </h2>
                <p className="mt-2 text-center text-sm text-gray-600">
                    Secure file sharing and collaboration platform
                </p>
            </div>

            <div className="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
                <div className="bg-white py-8 px-4 shadow-xl sm:rounded-lg sm:px-10 border border-gray-100">
                    <form className="space-y-6" onSubmit={handleSubmit}>
                        {/* Error Message */}
                        {error && (
                            <div className={`rounded-md p-4 ${isSuspended ? 'bg-orange-50 border border-orange-200' : 'bg-red-50 border border-red-200'}`}>
                                <div className="flex">
                                    <div className="flex-shrink-0">
                                        {isSuspended ? (
                                            <ShieldAlert className="h-5 w-5 text-orange-500" />
                                        ) : (
                                            <AlertCircle className="h-5 w-5 text-red-400" />
                                        )}
                                    </div>
                                    <div className="ml-3">
                                        <h3 className={`text-sm font-medium ${isSuspended ? 'text-orange-800' : 'text-red-800'}`}>
                                            {isSuspended ? 'Account Suspended' : 'Login Failed'}
                                        </h3>
                                        <p className={`text-sm mt-1 ${isSuspended ? 'text-orange-700' : 'text-red-700'}`}>
                                            {error}
                                        </p>
                                    </div>
                                </div>
                            </div>
                        )}

                        {!show2FA ? (
                            <>
                                {/* Email Field */}
                                <div>
                                    <label htmlFor="email" className="block text-sm font-medium text-gray-700">
                                        Email address
                                    </label>
                                    <div className="mt-1 relative">
                                        <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                                            <Mail className="h-5 w-5 text-gray-400" />
                                        </div>
                                        <input
                                            id="email"
                                            name="email"
                                            type="email"
                                            autoComplete="email"
                                            required
                                            value={email}
                                            onChange={(e) => setEmail(e.target.value)}
                                            className="appearance-none block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-primary-500 focus:border-primary-500 sm:text-sm text-gray-900 bg-white"
                                            placeholder="you@company.com"
                                        />
                                    </div>
                                </div>

                                {/* Password Field */}
                                <div>
                                    <label htmlFor="password" className="block text-sm font-medium text-gray-700">
                                        Password
                                    </label>
                                    <div className="mt-1 relative">
                                        <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                                            <Lock className="h-5 w-5 text-gray-400" />
                                        </div>
                                        <input
                                            id="password"
                                            name="password"
                                            type="password"
                                            autoComplete="current-password"
                                            required
                                            value={password}
                                            onChange={(e) => setPassword(e.target.value)}
                                            className="appearance-none block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-primary-500 focus:border-primary-500 sm:text-sm text-gray-900 bg-white"
                                            placeholder="••••••••"
                                        />
                                    </div>
                                </div>

                                {/* Remember Me & Forgot Password */}
                                <div className="flex items-center justify-between">
                                    <div className="flex items-center">
                                        <input
                                            id="remember-me"
                                            name="remember-me"
                                            type="checkbox"
                                            checked={rememberMe}
                                            onChange={(e) => setRememberMe(e.target.checked)}
                                            className="h-4 w-4 text-primary-600 focus:ring-primary-500 border-gray-300 rounded"
                                        />
                                        <label htmlFor="remember-me" className="ml-2 block text-sm text-gray-900">
                                            Remember me
                                        </label>
                                    </div>

                                    <div className="text-sm">
                                        <button
                                            type="button"
                                            onClick={() => setError('Please contact your administrator to reset your password.')}
                                            className="font-medium text-primary-600 hover:text-primary-500"
                                        >
                                            Forgot password?
                                        </button>
                                    </div>
                                </div>
                            </>
                        ) : (
                            /* 2FA Field */
                            <div>
                                <label htmlFor="code" className="block text-sm font-medium text-gray-700">
                                    Authentication Code
                                </label>
                                <div className="mt-1 relative">
                                    <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                                        <Lock className="h-5 w-5 text-gray-400" />
                                    </div>
                                        <input
                                            id="code"
                                            name="code"
                                            type="text"
                                            required
                                            value={code}
                                            onChange={(e) => setCode(e.target.value)}
                                            className="appearance-none block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-primary-500 focus:border-primary-500 sm:text-sm text-gray-900 bg-white"
                                            placeholder="123456"
                                        />
                                </div>
                                <p className="mt-2 text-sm text-gray-500">
                                    Enter the 6-digit code from your authenticator app.
                                </p>
                            </div>
                        )}

                        {/* Submit Button */}
                        <div>
                            <button
                                type="submit"
                                disabled={loading}
                                className="w-full flex justify-center py-2.5 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                            >
                                {loading ? (
                                    <div className="flex items-center">
                                        <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                                            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                                            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                                        </svg>
                                        {show2FA ? 'Verifying...' : 'Signing in...'}
                                    </div>
                                ) : (
                                    show2FA ? 'Verify Code' : 'Sign in'
                                )}
                            </button>
                        </div>
                    </form>
                </div>

                {/* Footer */}
                <p className="mt-6 text-center text-xs text-gray-500">
                    © {new Date().getFullYear()} ClovaLink. All rights reserved.
                </p>
            </div>
        </div>
    );
}
