'use client'

import { useQuery } from '@tanstack/react-query'
import { useState } from 'react'
import { motion } from 'framer-motion'
import { 
  AlertTriangle, Shield, Download, Filter, 
  ChevronDown, ChevronUp, Globe, Clock, 
  TrendingUp, AlertCircle, FileText 
} from 'lucide-react'
import toast from 'react-hot-toast'
import api from '@/lib/api'

interface AnalysisResultsProps {
  analysisId: string | null
}

export default function AnalysisResults({ analysisId }: AnalysisResultsProps) {
  const [expandedSections, setExpandedSections] = useState<string[]>(['summary'])
  const [filterOpen, setFilterOpen] = useState(false)
  const [filters, setFilters] = useState({
    ip: '',
    user: '',
    severity: '',
    startTime: '',
    endTime: '',
  })

  const { data: analysis, isLoading, isError } = useQuery({
    queryKey: ['analysis', analysisId],
    queryFn: () => api.getAnalysis(analysisId!),
    enabled: !!analysisId,
    refetchInterval: (data) => data?.status === 'processing' ? 2000 : false,
  })

  const toggleSection = (section: string) => {
    setExpandedSections(prev =>
      prev.includes(section)
        ? prev.filter(s => s !== section)
        : [...prev, section]
    )
  }

  const handleExport = async (format: string) => {
    if (!analysisId) return
    
    try {
      await api.exportAnalysis(analysisId, format)
      toast.success(`Exported as ${format.toUpperCase()}`)
    } catch (error) {
      toast.error('Export failed')
    }
  }

  const applyFilters = async () => {
    if (!analysisId) return
    
    try {
      const filteredLogs = await api.filterLogs(analysisId, filters)
      toast.success(`Found ${filteredLogs.total} matching logs`)
    } catch (error) {
      toast.error('Filter failed')
    }
  }

  if (!analysisId) {
    return (
      <div className="glass-effect rounded-xl p-12 text-center">
        <FileText className="w-16 h-16 mx-auto mb-4 text-gray-500" />
        <p className="text-gray-400">No analysis selected. Upload logs or connect to a server to start.</p>
      </div>
    )
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-500 mx-auto mb-4"></div>
          <p className="text-gray-400">Analyzing logs...</p>
        </div>
      </div>
    )
  }

  if (isError || !analysis) {
    return (
      <div className="glass-effect rounded-xl p-12 text-center">
        <AlertCircle className="w-16 h-16 mx-auto mb-4 text-red-400" />
        <p className="text-red-400">Failed to load analysis results</p>
      </div>
    )
  }

  const riskLevel = analysis.ai_insights?.summary?.risk_level || 'unknown'
  const riskColor = {
    critical: 'text-red-500 bg-red-500/20',
    high: 'text-orange-500 bg-orange-500/20',
    medium: 'text-yellow-500 bg-yellow-500/20',
    low: 'text-green-500 bg-green-500/20',
    unknown: 'text-gray-500 bg-gray-500/20',
  }[riskLevel]

  return (
    <div className="space-y-6">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="glass-effect rounded-xl p-6"
      >
        <div className="flex items-center justify-between mb-6">
          <div>
            <h2 className="text-2xl font-semibold text-white mb-2">Analysis Results</h2>
            <p className="text-gray-400">ID: {analysis.id}</p>
          </div>
          <div className="flex gap-3">
            <button
              onClick={() => setFilterOpen(!filterOpen)}
              className="px-4 py-2 bg-dark-800 hover:bg-dark-700 text-white rounded-lg flex items-center gap-2"
            >
              <Filter className="w-4 h-4" />
              Filter
            </button>
            <div className="relative group">
              <button className="px-4 py-2 bg-primary-600 hover:bg-primary-700 text-white rounded-lg flex items-center gap-2">
                <Download className="w-4 h-4" />
                Export
              </button>
              <div className="absolute right-0 mt-2 w-48 bg-dark-800 rounded-lg shadow-xl border border-dark-700 opacity-0 group-hover:opacity-100 pointer-events-none group-hover:pointer-events-auto transition-opacity">
                {['pdf', 'excel', 'word', 'csv'].map(format => (
                  <button
                    key={format}
                    onClick={() => handleExport(format)}
                    className="block w-full text-left px-4 py-2 text-gray-300 hover:bg-dark-700 hover:text-white"
                  >
                    Export as {format.toUpperCase()}
                  </button>
                ))}
              </div>
            </div>
          </div>
        </div>

        {filterOpen && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            className="mb-6 p-4 bg-dark-800 rounded-lg"
          >
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <input
                type="text"
                placeholder="IP Address"
                value={filters.ip}
                onChange={(e) => setFilters({ ...filters, ip: e.target.value })}
                className="px-3 py-2 bg-dark-700 border border-dark-600 rounded text-white"
              />
              <input
                type="text"
                placeholder="User"
                value={filters.user}
                onChange={(e) => setFilters({ ...filters, user: e.target.value })}
                className="px-3 py-2 bg-dark-700 border border-dark-600 rounded text-white"
              />
              <select
                value={filters.severity}
                onChange={(e) => setFilters({ ...filters, severity: e.target.value })}
                className="px-3 py-2 bg-dark-700 border border-dark-600 rounded text-white"
              >
                <option value="">All Severities</option>
                <option value="CRITICAL">Critical</option>
                <option value="ERROR">Error</option>
                <option value="WARNING">Warning</option>
                <option value="INFO">Info</option>
              </select>
              <input
                type="datetime-local"
                value={filters.startTime}
                onChange={(e) => setFilters({ ...filters, startTime: e.target.value })}
                className="px-3 py-2 bg-dark-700 border border-dark-600 rounded text-white"
              />
              <input
                type="datetime-local"
                value={filters.endTime}
                onChange={(e) => setFilters({ ...filters, endTime: e.target.value })}
                className="px-3 py-2 bg-dark-700 border border-dark-600 rounded text-white"
              />
              <button
                onClick={applyFilters}
                className="px-4 py-2 bg-primary-600 hover:bg-primary-700 text-white rounded"
              >
                Apply Filters
              </button>
            </div>
          </motion.div>
        )}

        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div className="bg-dark-800 rounded-lg p-4">
            <div className="flex items-center gap-2 mb-2">
              <Shield className="w-5 h-5 text-primary-400" />
              <span className="text-gray-400 text-sm">Risk Level</span>
            </div>
            <span className={`px-3 py-1 rounded-full text-sm font-medium ${riskColor}`}>
              {riskLevel.toUpperCase()}
            </span>
          </div>

          <div className="bg-dark-800 rounded-lg p-4">
            <div className="flex items-center gap-2 mb-2">
              <TrendingUp className="w-5 h-5 text-green-400" />
              <span className="text-gray-400 text-sm">Total Logs</span>
            </div>
            <p className="text-2xl font-bold text-white">{analysis.total_logs}</p>
          </div>

          <div className="bg-dark-800 rounded-lg p-4">
            <div className="flex items-center gap-2 mb-2">
              <AlertTriangle className="w-5 h-5 text-red-400" />
              <span className="text-gray-400 text-sm">Anomalies</span>
            </div>
            <p className="text-2xl font-bold text-white">
              {analysis.ai_insights?.summary?.total_anomalies || 0}
            </p>
          </div>

          <div className="bg-dark-800 rounded-lg p-4">
            <div className="flex items-center gap-2 mb-2">
              <Globe className="w-5 h-5 text-orange-400" />
              <span className="text-gray-400 text-sm">Suspicious IPs</span>
            </div>
            <p className="text-2xl font-bold text-white">
              {analysis.suspicious_ips?.length || 0}
            </p>
          </div>
        </div>
      </motion.div>

      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.1 }}
        className="glass-effect rounded-xl p-6"
      >
        <button
          onClick={() => toggleSection('insights')}
          className="w-full flex items-center justify-between text-white hover:text-primary-400 transition-colors"
        >
          <h3 className="text-xl font-semibold">AI Insights & Recommendations</h3>
          {expandedSections.includes('insights') ? (
            <ChevronUp className="w-5 h-5" />
          ) : (
            <ChevronDown className="w-5 h-5" />
          )}
        </button>

        {expandedSections.includes('insights') && analysis.ai_insights && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            className="mt-6 space-y-4"
          >
            {analysis.ai_insights.concerns && (
              <div>
                <h4 className="text-lg font-medium text-white mb-3">Security Concerns</h4>
                <ul className="space-y-2">
                  {analysis.ai_insights.concerns.map((concern: string, i: number) => (
                    <li key={i} className="flex items-start gap-2 text-gray-300">
                      <AlertCircle className="w-5 h-5 text-red-400 mt-0.5" />
                      <span>{concern}</span>
                    </li>
                  ))}
                </ul>
              </div>
            )}

            {analysis.ai_insights.recommendations && (
              <div>
                <h4 className="text-lg font-medium text-white mb-3">Recommendations</h4>
                <ul className="space-y-2">
                  {analysis.ai_insights.recommendations.map((rec: string, i: number) => (
                    <li key={i} className="flex items-start gap-2 text-gray-300">
                      <Shield className="w-5 h-5 text-green-400 mt-0.5" />
                      <span>{rec}</span>
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </motion.div>
        )}
      </motion.div>

      {analysis.suspicious_ips && analysis.suspicious_ips.length > 0 && (
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className="glass-effect rounded-xl p-6"
        >
          <button
            onClick={() => toggleSection('ips')}
            className="w-full flex items-center justify-between text-white hover:text-primary-400 transition-colors"
          >
            <h3 className="text-xl font-semibold">Suspicious IP Addresses</h3>
            {expandedSections.includes('ips') ? (
              <ChevronUp className="w-5 h-5" />
            ) : (
              <ChevronDown className="w-5 h-5" />
            )}
          </button>

          {expandedSections.includes('ips') && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              className="mt-6 overflow-x-auto"
            >
              <table className="w-full">
                <thead>
                  <tr className="border-b border-dark-600">
                    <th className="text-left pb-3 text-gray-400">IP Address</th>
                    <th className="text-left pb-3 text-gray-400">Risk Score</th>
                    <th className="text-left pb-3 text-gray-400">Sources</th>
                    <th className="text-left pb-3 text-gray-400">Status</th>
                  </tr>
                </thead>
                <tbody>
                  {analysis.suspicious_ips.map((ip: any, i: number) => (
                    <tr key={i} className="border-b border-dark-700">
                      <td className="py-3 text-white font-mono">{ip.ip}</td>
                      <td className="py-3">
                        <span className={`px-2 py-1 rounded text-xs ${
                          ip.risk_score > 75 ? 'bg-red-500/20 text-red-400' :
                          ip.risk_score > 50 ? 'bg-orange-500/20 text-orange-400' :
                          ip.risk_score > 25 ? 'bg-yellow-500/20 text-yellow-400' :
                          'bg-green-500/20 text-green-400'
                        }`}>
                          {ip.risk_score}%
                        </span>
                      </td>
                      <td className="py-3 text-gray-300">
                        {Object.keys(ip.sources || {}).join(', ')}
                      </td>
                      <td className="py-3">
                        {ip.is_malicious ? (
                          <span className="text-red-400">Malicious</span>
                        ) : (
                          <span className="text-green-400">Clean</span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </motion.div>
          )}
        </motion.div>
      )}
    </div>
  )
}