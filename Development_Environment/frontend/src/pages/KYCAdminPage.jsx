import React, { useState, useEffect } from 'react';
import {
  Container,
  Box,
  Typography,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Button,
  Chip,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  FormControlLabel,
  Checkbox,
  Grid,
  Card,
  CardContent,
  Alert,
  CircularProgress,
  IconButton,
  Tooltip
} from '@mui/material';
import {
  CheckCircle,
  Cancel,
  Refresh,
  VisibilityOutlined
} from '@mui/icons-material';
import { useSnackbar } from 'notistack';
import apiClient from '../services/apiClient';

/**
 * KYC Admin Dashboard
 * 
 * Administrative interface for reviewing pending KYC applications.
 * Features:
 * - List of pending applications
 * - Individual approve/reject with reason
 * - Batch operations
 * - Real-time status updates
 * 
 * TODO: Add authentication/authorization middleware
 * Currently accessible to any user (for testing purposes)
 */
const KYCAdminPage = () => {
  const { enqueueSnackbar } = useSnackbar();
  
  // State
  const [applications, setApplications] = useState([]);
  const [loading, setLoading] = useState(false);
  const [selectedApplication, setSelectedApplication] = useState(null);
  const [reviewDialogOpen, setReviewDialogOpen] = useState(false);
  const [rejectionReason, setRejectionReason] = useState('');
  const [addToWhitelist, setAddToWhitelist] = useState(true);
  const [selectedRows, setSelectedRows] = useState([]);
  const [submitting, setSubmitting] = useState(false);
  
  // Statistics
  const [stats, setStats] = useState({
    pending: 0,
    approvedToday: 0,
    rejectedToday: 0
  });

  // Fetch pending applications on mount and refresh
  useEffect(() => {
    fetchPendingApplications();
  }, []);

  const fetchPendingApplications = async () => {
    setLoading(true);
    try {
      const response = await apiClient.get('/kyc/admin/pending?limit=100');
      setApplications(response.data);
      
      // Update stats
      setStats(prev => ({
        ...prev,
        pending: response.data.length
      }));
    } catch (err) {
      console.error('Failed to fetch pending KYC applications:', err);
      enqueueSnackbar('Failed to load pending applications', { variant: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const handleRefresh = () => {
    fetchPendingApplications();
    enqueueSnackbar('Refreshed pending applications', { variant: 'info' });
  };

  const handleRowClick = (application) => {
    setSelectedApplication(application);
    setReviewDialogOpen(true);
    setRejectionReason('');
    setAddToWhitelist(true);
  };

  const handleCloseDialog = () => {
    setReviewDialogOpen(false);
    setSelectedApplication(null);
    setRejectionReason('');
  };

  const handleApprove = async () => {
    if (!selectedApplication) return;
    
    setSubmitting(true);
    try {
      await apiClient.post('/kyc/admin/review', {
        kyc_verification_id: selectedApplication.id,
        status: 'approved',  // Backend expects lowercase
        reviewer_address: '0x0000000000000000000000000000000000000000', // TODO: Use actual admin address
        add_to_whitelist: addToWhitelist
      });
      
      enqueueSnackbar(`Application approved for ${selectedApplication.full_name}`, { variant: 'success' });
      
      // Update stats
      setStats(prev => ({
        ...prev,
        pending: prev.pending - 1,
        approvedToday: prev.approvedToday + 1
      }));
      
      handleCloseDialog();
      fetchPendingApplications(); // Refresh list
    } catch (err) {
      console.error('Failed to approve application:', err);
      enqueueSnackbar(err.response?.data?.detail || 'Failed to approve application', { variant: 'error' });
    } finally {
      setSubmitting(false);
    }
  };

  const handleReject = async () => {
    if (!selectedApplication) return;
    
    if (!rejectionReason.trim()) {
      enqueueSnackbar('Rejection reason is required', { variant: 'warning' });
      return;
    }
    
    setSubmitting(true);
    try {
      await apiClient.post('/kyc/admin/review', {
        kyc_verification_id: selectedApplication.id,
        status: 'rejected',  // Backend expects lowercase
        reviewer_address: '0x0000000000000000000000000000000000000000', // TODO: Use actual admin address
        rejection_reason: rejectionReason,
        add_to_whitelist: false
      });
      
      enqueueSnackbar(`Application rejected for ${selectedApplication.full_name}`, { variant: 'info' });
      
      // Update stats
      setStats(prev => ({
        ...prev,
        pending: prev.pending - 1,
        rejectedToday: prev.rejectedToday + 1
      }));
      
      handleCloseDialog();
      fetchPendingApplications(); // Refresh list
    } catch (err) {
      console.error('Failed to reject application:', err);
      enqueueSnackbar(err.response?.data?.detail || 'Failed to reject application', { variant: 'error' });
    } finally {
      setSubmitting(false);
    }
  };

  const handleBatchApprove = async () => {
    if (selectedRows.length === 0) {
      enqueueSnackbar('Please select applications to approve', { variant: 'warning' });
      return;
    }
    
    setSubmitting(true);
    try {
      await apiClient.post('/kyc/admin/batch-review', {
        kyc_verification_ids: selectedRows,
        status: 'APPROVED',
        reviewer_address: '0x0000000000000000000000000000000000000000', // TODO: Use actual admin address
        add_to_whitelist: true
      });
      
      enqueueSnackbar(`Approved ${selectedRows.length} applications`, { variant: 'success' });
      setSelectedRows([]);
      fetchPendingApplications(); // Refresh list
    } catch (err) {
      console.error('Failed to batch approve:', err);
      enqueueSnackbar(err.response?.data?.detail || 'Failed to batch approve', { variant: 'error' });
    } finally {
      setSubmitting(false);
    }
  };

  const handleBatchReject = async () => {
    if (selectedRows.length === 0) {
      enqueueSnackbar('Please select applications to reject', { variant: 'warning' });
      return;
    }
    
    const reason = prompt('Enter rejection reason for all selected applications:');
    if (!reason || !reason.trim()) {
      enqueueSnackbar('Rejection reason is required', { variant: 'warning' });
      return;
    }
    
    setSubmitting(true);
    try {
      await apiClient.post('/kyc/admin/batch-review', {
        kyc_verification_ids: selectedRows,
        status: 'REJECTED',
        reviewer_address: '0x0000000000000000000000000000000000000000', // TODO: Use actual admin address
        add_to_whitelist: false
      });
      
      enqueueSnackbar(`Rejected ${selectedRows.length} applications`, { variant: 'info' });
      setSelectedRows([]);
      fetchPendingApplications(); // Refresh list
    } catch (err) {
      console.error('Failed to batch reject:', err);
      enqueueSnackbar(err.response?.data?.detail || 'Failed to batch reject', { variant: 'error' });
    } finally {
      setSubmitting(false);
    }
  };

  const toggleRowSelection = (id) => {
    setSelectedRows(prev => 
      prev.includes(id) 
        ? prev.filter(rowId => rowId !== id)
        : [...prev, id]
    );
  };

  const toggleSelectAll = () => {
    if (selectedRows.length === applications.length) {
      setSelectedRows([]);
    } else {
      setSelectedRows(applications.map(app => app.id));
    }
  };

  const formatDate = (dateString) => {
    if (!dateString) return 'N/A';
    return new Date(dateString).toLocaleString();
  };

  const formatAddress = (address) => {
    if (!address || address.length < 10) return address;
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  };

  return (
    <Container maxWidth="xl" sx={{ py: 4 }}>
      <Box sx={{ mb: 4 }}>
        <Typography variant="h4" component="h1" gutterBottom>
          KYC Admin Dashboard
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Review and manage pending KYC applications
        </Typography>
      </Box>

      {/* Statistics Cards */}
      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Typography variant="h6" color="warning.main">
                {stats.pending}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Pending Applications
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Typography variant="h6" color="success.main">
                {stats.approvedToday}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Approved Today
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Typography variant="h6" color="error.main">
                {stats.rejectedToday}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Rejected Today
              </Typography>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Batch Actions */}
      {selectedRows.length > 0 && (
        <Alert severity="info" sx={{ mb: 2 }}>
          {selectedRows.length} application(s) selected
          <Box sx={{ mt: 1 }}>
            <Button
              variant="contained"
              color="success"
              size="small"
              onClick={handleBatchApprove}
              disabled={submitting}
              sx={{ mr: 1 }}
            >
              Batch Approve
            </Button>
            <Button
              variant="contained"
              color="error"
              size="small"
              onClick={handleBatchReject}
              disabled={submitting}
            >
              Batch Reject
            </Button>
          </Box>
        </Alert>
      )}

      {/* Applications Table */}
      <Paper>
        <Box sx={{ p: 2, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Typography variant="h6">
            Pending Applications
          </Typography>
          <Button
            variant="outlined"
            startIcon={<Refresh />}
            onClick={handleRefresh}
            disabled={loading}
          >
            Refresh
          </Button>
        </Box>

        {loading ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
            <CircularProgress />
          </Box>
        ) : applications.length === 0 ? (
          <Box sx={{ p: 4, textAlign: 'center' }}>
            <Typography variant="body1" color="text.secondary">
              No pending applications
            </Typography>
          </Box>
        ) : (
          <TableContainer>
            <Table>
              <TableHead>
                <TableRow>
                  <TableCell padding="checkbox">
                    <Checkbox
                      checked={selectedRows.length === applications.length && applications.length > 0}
                      indeterminate={selectedRows.length > 0 && selectedRows.length < applications.length}
                      onChange={toggleSelectAll}
                    />
                  </TableCell>
                  <TableCell>Name</TableCell>
                  <TableCell>Email</TableCell>
                  <TableCell>Wallet Address</TableCell>
                  <TableCell>Tier</TableCell>
                  <TableCell>Submitted</TableCell>
                  <TableCell>Actions</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {applications.map((application) => (
                  <TableRow 
                    key={application.id}
                    hover
                    sx={{ cursor: 'pointer' }}
                  >
                    <TableCell padding="checkbox">
                      <Checkbox
                        checked={selectedRows.includes(application.id)}
                        onChange={() => toggleRowSelection(application.id)}
                        onClick={(e) => e.stopPropagation()}
                      />
                    </TableCell>
                    <TableCell onClick={() => handleRowClick(application)}>
                      {application.full_name}
                    </TableCell>
                    <TableCell onClick={() => handleRowClick(application)}>
                      {application.email}
                    </TableCell>
                    <TableCell onClick={() => handleRowClick(application)}>
                      <Tooltip title={application.wallet_address}>
                        <span>{formatAddress(application.wallet_address)}</span>
                      </Tooltip>
                    </TableCell>
                    <TableCell onClick={() => handleRowClick(application)}>
                      <Chip 
                        label={application.tier}
                        size="small"
                        sx={{ textTransform: 'capitalize' }}
                      />
                    </TableCell>
                    <TableCell onClick={() => handleRowClick(application)}>
                      {formatDate(application.submission_date)}
                    </TableCell>
                    <TableCell>
                      <Tooltip title="Review">
                        <IconButton 
                          size="small"
                          onClick={(e) => {
                            e.stopPropagation();
                            handleRowClick(application);
                          }}
                        >
                          <VisibilityOutlined />
                        </IconButton>
                      </Tooltip>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TableContainer>
        )}
      </Paper>

      {/* Review Dialog */}
      <Dialog 
        open={reviewDialogOpen} 
        onClose={handleCloseDialog}
        maxWidth="sm"
        fullWidth
      >
        <DialogTitle>
          Review KYC Application
        </DialogTitle>
        <DialogContent>
          {selectedApplication && (
            <Box sx={{ pt: 1 }}>
              <Grid container spacing={2}>
                <Grid item xs={12}>
                  <Typography variant="subtitle2" color="text.secondary">
                    Applicant Name
                  </Typography>
                  <Typography variant="body1">
                    {selectedApplication.full_name}
                  </Typography>
                </Grid>
                <Grid item xs={12}>
                  <Typography variant="subtitle2" color="text.secondary">
                    Email
                  </Typography>
                  <Typography variant="body1">
                    {selectedApplication.email}
                  </Typography>
                </Grid>
                <Grid item xs={12}>
                  <Typography variant="subtitle2" color="text.secondary">
                    Wallet Address
                  </Typography>
                  <Typography variant="body1" sx={{ fontFamily: 'monospace', fontSize: '0.9rem' }}>
                    {selectedApplication.wallet_address}
                  </Typography>
                </Grid>
                <Grid item xs={12}>
                  <Typography variant="subtitle2" color="text.secondary">
                    Country
                  </Typography>
                  <Typography variant="body1">
                    {selectedApplication.country}
                  </Typography>
                </Grid>
                <Grid item xs={12}>
                  <Typography variant="subtitle2" color="text.secondary">
                    Tier
                  </Typography>
                  <Chip 
                    label={selectedApplication.tier}
                    size="small"
                    sx={{ textTransform: 'capitalize' }}
                  />
                </Grid>
                <Grid item xs={12}>
                  <Typography variant="subtitle2" color="text.secondary">
                    Submitted
                  </Typography>
                  <Typography variant="body1">
                    {formatDate(selectedApplication.submitted_at)}
                  </Typography>
                </Grid>
              </Grid>

              <Box sx={{ mt: 3 }}>
                <TextField
                  fullWidth
                  multiline
                  rows={3}
                  label="Rejection Reason (required if rejecting)"
                  value={rejectionReason}
                  onChange={(e) => setRejectionReason(e.target.value)}
                  helperText="Provide a clear reason if rejecting this application"
                />
              </Box>

              <Box sx={{ mt: 2 }}>
                <FormControlLabel
                  control={
                    <Checkbox
                      checked={addToWhitelist}
                      onChange={(e) => setAddToWhitelist(e.target.checked)}
                    />
                  }
                  label="Add to blockchain whitelist (if approved)"
                />
                <Typography variant="caption" display="block" color="text.secondary" sx={{ ml: 4 }}>
                  Approved addresses will be added to the on-chain KYC whitelist
                </Typography>
              </Box>
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={handleCloseDialog} disabled={submitting}>
            Cancel
          </Button>
          <Button 
            onClick={handleReject}
            color="error"
            variant="contained"
            startIcon={<Cancel />}
            disabled={submitting}
          >
            Reject
          </Button>
          <Button 
            onClick={handleApprove}
            color="success"
            variant="contained"
            startIcon={<CheckCircle />}
            disabled={submitting}
          >
            Approve
          </Button>
        </DialogActions>
      </Dialog>
    </Container>
  );
};

export default KYCAdminPage;

