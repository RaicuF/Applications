'use client'

import { useState } from 'react'
import { motion } from 'framer-motion'
import { Shield, Upload, Server, BarChart3, FileText, AlertCircle } from 'lucide-react'
import Dashboard from '@/components/Dashboard'
import UploadSection from '@/components/UploadSection'
import ServerConnect from '@/components/ServerConnect'
import AnalysisResults from '@/components/AnalysisResults'
import Navbar from '@/components/Navbar'

export default function Home() {
  const [activeTab, setActiveTab] = useState('dashboard')
  const [currentAnalysis, setCurrentAnalysis] = useState<string | null>(null)

  const tabs = [
    { id: 'dashboard', label: 'Dashboard', icon: BarChart3 },
    { id: 'upload', label: 'Upload Logs', icon: Upload },
    { id: 'server', label: 'Connect Server', icon: Server },
    { id: 'analysis', label: 'Analysis', icon: FileText },
  ]

  return (
    <div className="min-h-screen bg-gradient-to-br from-dark-900 via-dark-800 to-primary-900">
      <Navbar />
      
      <main className="container mx-auto px-4 py-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="mb-8"
        >
          <div className="flex items-center gap-3 mb-6">
            <Shield className="w-10 h-10 text-primary-400" />
            <h1 className="text-4xl font-bold text-white">AI Log Analyzer Pro</h1>
          </div>
          
          <div className="flex gap-4 border-b border-dark-600">
            {tabs.map((tab) => {
              const Icon = tab.icon
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  className={`flex items-center gap-2 px-4 py-3 border-b-2 transition-all ${
                    activeTab === tab.id
                      ? 'border-primary-500 text-primary-400'
                      : 'border-transparent text-gray-400 hover:text-gray-300'
                  }`}
                >
                  <Icon className="w-5 h-5" />
                  <span>{tab.label}</span>
                </button>
              )
            })}
          </div>
        </motion.div>

        <motion.div
          key={activeTab}
          initial={{ opacity: 0, x: 20 }}
          animate={{ opacity: 1, x: 0 }}
          exit={{ opacity: 0, x: -20 }}
          transition={{ duration: 0.3 }}
        >
          {activeTab === 'dashboard' && <Dashboard />}
          {activeTab === 'upload' && (
            <UploadSection onAnalysisStart={(id) => {
              setCurrentAnalysis(id)
              setActiveTab('analysis')
            }} />
          )}
          {activeTab === 'server' && (
            <ServerConnect onAnalysisStart={(id) => {
              setCurrentAnalysis(id)
              setActiveTab('analysis')
            }} />
          )}
          {activeTab === 'analysis' && (
            <AnalysisResults analysisId={currentAnalysis} />
          )}
        </motion.div>

        {activeTab === 'dashboard' && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.5 }}
            className="mt-12 grid grid-cols-1 md:grid-cols-3 gap-6"
          >
            <div className="glass-effect rounded-xl p-6 text-white">
              <div className="flex items-center gap-3 mb-4">
                <Upload className="w-8 h-8 text-primary-400" />
                <h3 className="text-xl font-semibold">Easy Upload</h3>
              </div>
              <p className="text-gray-300">
                Support for multiple log formats including Apache, Nginx, Syslog, JSON, CSV, and XML
              </p>
            </div>

            <div className="glass-effect rounded-xl p-6 text-white">
              <div className="flex items-center gap-3 mb-4">
                <Shield className="w-8 h-8 text-green-400" />
                <h3 className="text-xl font-semibold">AI Security Analysis</h3>
              </div>
              <p className="text-gray-300">
                Advanced AI-powered analysis using Llama models to detect security threats and anomalies
              </p>
            </div>

            <div className="glass-effect rounded-xl p-6 text-white">
              <div className="flex items-center gap-3 mb-4">
                <AlertCircle className="w-8 h-8 text-red-400" />
                <h3 className="text-xl font-semibold">IP Reputation</h3>
              </div>
              <p className="text-gray-300">
                Integration with VirusTotal and AbuseIPDB for comprehensive IP reputation checking
              </p>
            </div>
          </motion.div>
        )}
      </main>
    </div>
  )
}