'use client'

import { useCallback, useState } from 'react'
import { useDropzone } from 'react-dropzone'
import { Upload, File, X, CheckCircle, AlertCircle } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import toast from 'react-hot-toast'
import api from '@/lib/api'

interface UploadSectionProps {
  onAnalysisStart: (analysisId: string) => void
}

export default function UploadSection({ onAnalysisStart }: UploadSectionProps) {
  const [files, setFiles] = useState<File[]>([])
  const [uploading, setUploading] = useState(false)

  const onDrop = useCallback((acceptedFiles: File[]) => {
    setFiles(prev => [...prev, ...acceptedFiles])
  }, [])

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      'text/plain': ['.log', '.txt'],
      'application/json': ['.json'],
      'text/csv': ['.csv'],
      'application/xml': ['.xml'],
      'text/xml': ['.xml'],
    },
    multiple: true,
  })

  const removeFile = (index: number) => {
    setFiles(prev => prev.filter((_, i) => i !== index))
  }

  const handleUpload = async () => {
    if (files.length === 0) {
      toast.error('Please select files to upload')
      return
    }

    setUploading(true)
    try {
      const formData = new FormData()
      files.forEach(file => {
        formData.append('files', file)
      })

      const response = await api.uploadLogs(formData)
      toast.success('Files uploaded successfully!')
      onAnalysisStart(response.analysis_id)
      setFiles([])
    } catch (error) {
      toast.error('Upload failed. Please try again.')
      console.error(error)
    } finally {
      setUploading(false)
    }
  }

  return (
    <div className="space-y-6">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="glass-effect rounded-xl p-8"
      >
        <h2 className="text-2xl font-semibold text-white mb-6">Upload Log Files</h2>
        
        <div
          {...getRootProps()}
          className={`border-2 border-dashed rounded-xl p-12 text-center cursor-pointer transition-all ${
            isDragActive
              ? 'border-primary-400 bg-primary-400/10'
              : 'border-dark-600 hover:border-primary-500'
          }`}
        >
          <input {...getInputProps()} />
          <Upload className="w-16 h-16 mx-auto mb-4 text-primary-400" />
          <p className="text-white text-lg mb-2">
            {isDragActive
              ? 'Drop the files here...'
              : 'Drag & drop log files here, or click to select'}
          </p>
          <p className="text-gray-400 text-sm">
            Supported formats: .log, .txt, .json, .csv, .xml
          </p>
        </div>

        <AnimatePresence>
          {files.length > 0 && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              exit={{ opacity: 0, height: 0 }}
              className="mt-6 space-y-2"
            >
              <h3 className="text-lg font-medium text-white mb-3">Selected Files</h3>
              {files.map((file, index) => (
                <motion.div
                  key={`${file.name}-${index}`}
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: 20 }}
                  className="flex items-center justify-between bg-dark-800 rounded-lg p-3"
                >
                  <div className="flex items-center gap-3">
                    <File className="w-5 h-5 text-primary-400" />
                    <div>
                      <p className="text-white">{file.name}</p>
                      <p className="text-gray-400 text-sm">
                        {(file.size / 1024).toFixed(2)} KB
                      </p>
                    </div>
                  </div>
                  <button
                    onClick={() => removeFile(index)}
                    className="p-1 hover:bg-dark-700 rounded"
                  >
                    <X className="w-5 h-5 text-gray-400" />
                  </button>
                </motion.div>
              ))}
            </motion.div>
          )}
        </AnimatePresence>

        {files.length > 0 && (
          <motion.button
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            onClick={handleUpload}
            disabled={uploading}
            className="mt-6 w-full py-3 bg-primary-600 hover:bg-primary-700 text-white rounded-lg font-medium transition-colors disabled:opacity-50"
          >
            {uploading ? (
              <span className="flex items-center justify-center gap-2">
                <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white"></div>
                Analyzing...
              </span>
            ) : (
              'Start Analysis'
            )}
          </motion.button>
        )}
      </motion.div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <motion.div
          initial={{ opacity: 0, x: -20 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ delay: 0.2 }}
          className="glass-effect rounded-xl p-6"
        >
          <div className="flex items-center gap-3 mb-4">
            <CheckCircle className="w-8 h-8 text-green-400" />
            <h3 className="text-xl font-semibold text-white">Supported Formats</h3>
          </div>
          <ul className="space-y-2 text-gray-300">
            <li>• Apache/Nginx access logs</li>
            <li>• System logs (syslog)</li>
            <li>• JSON structured logs</li>
            <li>• CSV log exports</li>
            <li>• Windows Event logs</li>
          </ul>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, x: 20 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ delay: 0.3 }}
          className="glass-effect rounded-xl p-6"
        >
          <div className="flex items-center gap-3 mb-4">
            <AlertCircle className="w-8 h-8 text-yellow-400" />
            <h3 className="text-xl font-semibold text-white">Analysis Features</h3>
          </div>
          <ul className="space-y-2 text-gray-300">
            <li>• AI-powered threat detection</li>
            <li>• Anomaly identification</li>
            <li>• IP reputation checking</li>
            <li>• Pattern recognition</li>
            <li>• Security recommendations</li>
          </ul>
        </motion.div>
      </div>
    </div>
  )
}