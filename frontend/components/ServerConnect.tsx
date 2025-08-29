'use client'

import { useState } from 'react'
import { Server, Key, Lock, Terminal, CheckCircle } from 'lucide-react'
import { motion } from 'framer-motion'
import toast from 'react-hot-toast'
import api from '@/lib/api'

interface ServerConnectProps {
  onAnalysisStart: (analysisId: string) => void
}

export default function ServerConnect({ onAnalysisStart }: ServerConnectProps) {
  const [connectionType, setConnectionType] = useState<'password' | 'key'>('password')
  const [formData, setFormData] = useState({
    host: '',
    port: '22',
    username: '',
    password: '',
    keyPath: '',
    logPaths: '/var/log/syslog',
  })
  const [connecting, setConnecting] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    
    if (!formData.host || !formData.username) {
      toast.error('Please fill in all required fields')
      return
    }

    setConnecting(true)
    try {
      const config = {
        host: formData.host,
        port: parseInt(formData.port),
        username: formData.username,
        ...(connectionType === 'password' 
          ? { password: formData.password }
          : { key_path: formData.keyPath }),
        log_paths: formData.logPaths.split(',').map(p => p.trim()),
      }

      const response = await api.connectToServer(config)
      toast.success('Successfully connected and fetched logs!')
      onAnalysisStart(response.analysis_id)
    } catch (error) {
      toast.error('Connection failed. Please check your credentials.')
      console.error(error)
    } finally {
      setConnecting(false)
    }
  }

  return (
    <div className="space-y-6">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="glass-effect rounded-xl p-8"
      >
        <h2 className="text-2xl font-semibold text-white mb-6">Connect to Server</h2>
        
        <form onSubmit={handleSubmit} className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label className="block text-gray-300 mb-2">Server Host *</label>
              <div className="relative">
                <Server className="absolute left-3 top-3 w-5 h-5 text-gray-500" />
                <input
                  type="text"
                  value={formData.host}
                  onChange={(e) => setFormData({ ...formData, host: e.target.value })}
                  className="w-full pl-10 pr-3 py-3 bg-dark-800 border border-dark-600 rounded-lg text-white focus:border-primary-500 focus:outline-none"
                  placeholder="192.168.1.1 or domain.com"
                />
              </div>
            </div>

            <div>
              <label className="block text-gray-300 mb-2">Port</label>
              <input
                type="text"
                value={formData.port}
                onChange={(e) => setFormData({ ...formData, port: e.target.value })}
                className="w-full px-3 py-3 bg-dark-800 border border-dark-600 rounded-lg text-white focus:border-primary-500 focus:outline-none"
                placeholder="22"
              />
            </div>

            <div>
              <label className="block text-gray-300 mb-2">Username *</label>
              <input
                type="text"
                value={formData.username}
                onChange={(e) => setFormData({ ...formData, username: e.target.value })}
                className="w-full px-3 py-3 bg-dark-800 border border-dark-600 rounded-lg text-white focus:border-primary-500 focus:outline-none"
                placeholder="root"
              />
            </div>

            <div>
              <label className="block text-gray-300 mb-2">Authentication Type</label>
              <div className="flex gap-3">
                <button
                  type="button"
                  onClick={() => setConnectionType('password')}
                  className={`flex-1 py-3 rounded-lg border transition-all ${
                    connectionType === 'password'
                      ? 'bg-primary-600 border-primary-600 text-white'
                      : 'bg-dark-800 border-dark-600 text-gray-400'
                  }`}
                >
                  <Lock className="w-5 h-5 mx-auto mb-1" />
                  Password
                </button>
                <button
                  type="button"
                  onClick={() => setConnectionType('key')}
                  className={`flex-1 py-3 rounded-lg border transition-all ${
                    connectionType === 'key'
                      ? 'bg-primary-600 border-primary-600 text-white'
                      : 'bg-dark-800 border-dark-600 text-gray-400'
                  }`}
                >
                  <Key className="w-5 h-5 mx-auto mb-1" />
                  SSH Key
                </button>
              </div>
            </div>
          </div>

          {connectionType === 'password' ? (
            <div>
              <label className="block text-gray-300 mb-2">Password *</label>
              <input
                type="password"
                value={formData.password}
                onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                className="w-full px-3 py-3 bg-dark-800 border border-dark-600 rounded-lg text-white focus:border-primary-500 focus:outline-none"
                placeholder="••••••••"
              />
            </div>
          ) : (
            <div>
              <label className="block text-gray-300 mb-2">SSH Key Path *</label>
              <input
                type="text"
                value={formData.keyPath}
                onChange={(e) => setFormData({ ...formData, keyPath: e.target.value })}
                className="w-full px-3 py-3 bg-dark-800 border border-dark-600 rounded-lg text-white focus:border-primary-500 focus:outline-none"
                placeholder="/home/user/.ssh/id_rsa"
              />
            </div>
          )}

          <div>
            <label className="block text-gray-300 mb-2">Log Paths (comma-separated)</label>
            <textarea
              value={formData.logPaths}
              onChange={(e) => setFormData({ ...formData, logPaths: e.target.value })}
              className="w-full px-3 py-3 bg-dark-800 border border-dark-600 rounded-lg text-white focus:border-primary-500 focus:outline-none"
              rows={3}
              placeholder="/var/log/syslog, /var/log/auth.log, /var/log/apache2/access.log"
            />
          </div>

          <button
            type="submit"
            disabled={connecting}
            className="w-full py-3 bg-primary-600 hover:bg-primary-700 text-white rounded-lg font-medium transition-colors disabled:opacity-50"
          >
            {connecting ? (
              <span className="flex items-center justify-center gap-2">
                <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white"></div>
                Connecting...
              </span>
            ) : (
              'Connect & Analyze'
            )}
          </button>
        </form>
      </motion.div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <motion.div
          initial={{ opacity: 0, x: -20 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ delay: 0.2 }}
          className="glass-effect rounded-xl p-6"
        >
          <div className="flex items-center gap-3 mb-4">
            <Terminal className="w-8 h-8 text-blue-400" />
            <h3 className="text-xl font-semibold text-white">Supported Systems</h3>
          </div>
          <ul className="space-y-2 text-gray-300">
            <li>• Linux (Ubuntu, CentOS, Debian)</li>
            <li>• Unix-based systems</li>
            <li>• Cloud instances (AWS, Azure, GCP)</li>
            <li>• Docker containers</li>
            <li>• Kubernetes pods</li>
          </ul>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, x: 20 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ delay: 0.3 }}
          className="glass-effect rounded-xl p-6"
        >
          <div className="flex items-center gap-3 mb-4">
            <CheckCircle className="w-8 h-8 text-green-400" />
            <h3 className="text-xl font-semibold text-white">Security Features</h3>
          </div>
          <ul className="space-y-2 text-gray-300">
            <li>• Encrypted SSH connections</li>
            <li>• No credentials stored</li>
            <li>• Read-only access</li>
            <li>• Session timeout protection</li>
            <li>• Audit trail logging</li>
          </ul>
        </motion.div>
      </div>
    </div>
  )
}