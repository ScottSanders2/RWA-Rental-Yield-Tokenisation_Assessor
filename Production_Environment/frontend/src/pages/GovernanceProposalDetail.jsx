import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
  Container,
  Paper,
  Typography,
  Box,
  Button,
  Grid,
  Chip,
  Divider,
  Alert,
  CircularProgress,
  Card,
  CardContent,
  LinearProgress,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  ButtonGroup
} from '@mui/material';
import ArrowBackIcon from '@mui/icons-material/ArrowBack';
import HowToVoteIcon from '@mui/icons-material/HowToVote';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import CancelIcon from '@mui/icons-material/Cancel';
import ThumbUpIcon from '@mui/icons-material/ThumbUp';
import ThumbDownIcon from '@mui/icons-material/ThumbDown';
import RemoveCircleOutlineIcon from '@mui/icons-material/RemoveCircleOutline';
import UserProfileSwitcher from '../components/UserProfileSwitcher';
import { getProposals, castVote, getVotingPower } from '../services/apiClient';

/**
 * GovernanceProposalDetail - Displays full details of a governance proposal
 * 
 * Shows proposal information, voting status, and allows voting on active proposals.
 * Uses apiClient for all API calls to ensure proper routing through NGINX in production.
 * Includes user profile switcher for multi-voter governance testing.
 */
function GovernanceProposalDetail() {
  const { proposalId } = useParams();
  const navigate = useNavigate();
  
  const [proposal, setProposal] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [voteDialogOpen, setVoteDialogOpen] = useState(false);
  const [votingPower, setVotingPower] = useState(0);
  const [hasVoted, setHasVoted] = useState(false);
  const [voting, setVoting] = useState(false);
  const [voteSuccess, setVoteSuccess] = useState(null);
  const [currentProfile, setCurrentProfile] = useState(null);

  useEffect(() => {
    fetchProposalDetail();
  }, [proposalId]);

  // Reload voting status and power when profile changes
  useEffect(() => {
    if (currentProfile && proposal) {
      checkVotedStatus();
      fetchVotingPower();
    }
  }, [currentProfile, proposal?.agreement_id]);

  const handleProfileChange = (profile) => {
    console.log('👤 Profile changed to:', profile.display_name);
    setCurrentProfile(profile);
    setVoteSuccess(null); // Clear any previous vote messages
  };

  const checkVotedStatus = async () => {
    if (!currentProfile) return;
    
    try {
      // Check if current user has voted using localStorage (temp until blockchain integration)
      const votedProposals = JSON.parse(localStorage.getItem('votedProposals') || '{}');
      const proposalVotes = votedProposals[proposalId] || {};
      setHasVoted(!!proposalVotes[currentProfile.wallet_address]);
      if (proposalVotes[currentProfile.wallet_address]) {
        console.log(`✅ ${currentProfile.display_name} has already voted on proposal ${proposalId}`);
      }
    } catch (err) {
      console.error('Error checking voted status:', err);
    }
  };

  const fetchVotingPower = async () => {
    if (!currentProfile || !proposal) return;
    
    try {
      const response = await getVotingPower(
        currentProfile.wallet_address,
        proposal.agreement_id,
        'ERC721'
      );
      setVotingPower(response.data.voting_power);
      console.log(`📊 ${currentProfile.display_name} voting power: ${response.data.voting_power.toLocaleString()} tokens`);
    } catch (err) {
      console.error('Error fetching voting power:', err);
      setVotingPower(10000); // Fallback
    }
  };

  const fetchProposalDetail = async () => {
    try {
      setLoading(true);
      const response = await getProposals();
      const proposals = response.data || [];
      const foundProposal = proposals.find(p => p.proposal_id === parseInt(proposalId));
      if (foundProposal) {
        setProposal(foundProposal);
      } else {
        setError('Proposal not found');
      }
    } catch (err) {
      setError('Failed to load proposal. Ensure backend is running.');
      console.error('Error fetching proposal:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleVote = async (support) => {
    if (!currentProfile) {
      setError('Please select a user profile to vote');
      return;
    }
    
    const supportLabels = { 0: 'Against', 1: 'For', 2: 'Abstain' };
    
    setVoting(true);
    setVoteSuccess(null);
    
    try {
      const response = await castVote({
        proposal_id: parseInt(proposalId),
        support,
        token_standard: 'ERC721',
        voter_address: currentProfile.wallet_address
      });

      // Mark as voted in local storage (track by proposal and user)
      const votedProposals = JSON.parse(localStorage.getItem('votedProposals') || '{}');
      if (!votedProposals[proposalId]) {
        votedProposals[proposalId] = {};
      }
      votedProposals[proposalId][currentProfile.wallet_address] = { 
        support, 
        timestamp: new Date().toISOString(),
        displayName: currentProfile.display_name 
      };
      localStorage.setItem('votedProposals', JSON.stringify(votedProposals));

      setHasVoted(true);
      setVoteSuccess(`${currentProfile.display_name} voted: ${supportLabels[support]}`);
      setVoteDialogOpen(false);
      
      // Refresh proposal data
      await fetchProposalDetail();
    } catch (err) {
      setError(err.message || 'Failed to cast vote');
      console.error('Error casting vote:', err);
    } finally {
      setVoting(false);
    }
  };

  const getStatusColor = (status) => {
    const colors = {
      'PENDING': 'warning',
      'ACTIVE': 'info',
      'SUCCEEDED': 'success',
      'DEFEATED': 'error',
      'EXECUTED': 'primary',
      'CANCELLED': 'default'
    };
    return colors[status] || 'default';
  };

  const getProposalTypeLabel = (type) => {
    const labels = {
      'ROI_ADJUSTMENT': 'ROI Adjustment',
      'RESERVE_ALLOCATION': 'Reserve Allocation',
      'RESERVE_WITHDRAWAL': 'Reserve Withdrawal',
      'PARAMETER_UPDATE': 'Parameter Update'
    };
    return labels[type] || type;
  };

  const formatTargetValue = (type, value) => {
    if (type === 'ROI_ADJUSTMENT') {
      return `${(value / 100).toFixed(2)}% (${value} basis points)`;
    } else if (type === 'RESERVE_ALLOCATION' || type === 'RESERVE_WITHDRAWAL') {
      return `${(value / 1e18).toFixed(4)} ETH`;
    } else {
      return value;
    }
  };

  const calculateVotePercentages = () => {
    if (!proposal) return { forPercent: 0, againstPercent: 0, abstainPercent: 0 };
    
    const total = proposal.for_votes + proposal.against_votes + proposal.abstain_votes;
    if (total === 0) return { forPercent: 0, againstPercent: 0, abstainPercent: 0 };
    
    return {
      forPercent: (proposal.for_votes / total) * 100,
      againstPercent: (proposal.against_votes / total) * 100,
      abstainPercent: (proposal.abstain_votes / total) * 100
    };
  };

  if (loading) {
    return (
      <Container maxWidth="lg" sx={{ py: 4, textAlign: 'center' }}>
        <CircularProgress size={60} />
        <Typography variant="h6" sx={{ mt: 2 }}>
          Loading proposal details...
        </Typography>
      </Container>
    );
  }

  if (error || !proposal) {
    return (
      <Container maxWidth="lg" sx={{ py: 4 }}>
        <Alert severity="error" sx={{ mb: 3 }}>
          {error || 'Proposal not found'}
        </Alert>
        <Button
          variant="contained"
          startIcon={<ArrowBackIcon />}
          onClick={() => navigate('/governance')}
        >
          Back to Governance
        </Button>
      </Container>
    );
  }

  const votePercentages = calculateVotePercentages();

  return (
    <Container maxWidth="lg" sx={{ py: 4 }}>
      {/* User Profile Switcher for Multi-Voter Testing */}
      <UserProfileSwitcher
        onProfileChange={handleProfileChange}
        currentProfile={currentProfile}
      />

      {/* Back Button */}
      <Button
        startIcon={<ArrowBackIcon />}
        onClick={() => navigate('/governance')}
        sx={{ mb: 3 }}
      >
        Back to Governance Dashboard
      </Button>

      {/* Proposal Header */}
      <Paper elevation={3} sx={{ p: 4, mb: 3 }}>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 2 }}>
          <Box>
            <Typography variant="h4" gutterBottom>
              Proposal #{proposal.proposal_id}
            </Typography>
            <Box sx={{ display: 'flex', gap: 1, mt: 1 }}>
              <Chip 
                label={getProposalTypeLabel(proposal.proposal_type)} 
                color="primary" 
                size="small"
              />
              <Chip 
                label={proposal.status || 'PENDING'} 
                color={getStatusColor(proposal.status || 'PENDING')} 
                size="small"
              />
            </Box>
          </Box>
          {proposal.status === 'ACTIVE' && !hasVoted && votingPower > 0 && (
            <Button
              variant="contained"
              startIcon={<HowToVoteIcon />}
              color="primary"
              onClick={() => setVoteDialogOpen(true)}
            >
              Cast Vote
            </Button>
          )}
          {hasVoted && (
            <Chip
              icon={<CheckCircleIcon />}
              label="Voted"
              color="success"
              size="medium"
            />
          )}
        </Box>

        <Divider sx={{ my: 3 }} />

        {/* Description */}
        <Typography variant="h6" gutterBottom>
          Description
        </Typography>
        <Typography variant="body1" paragraph>
          {proposal.description}
        </Typography>
      </Paper>

      {/* Proposal Details Grid */}
      <Grid container spacing={3}>
        {/* Left Column - Proposal Info */}
        <Grid item xs={12} md={6}>
          <Card elevation={2}>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Proposal Details
              </Typography>
              <Divider sx={{ mb: 2 }} />
              
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                <Box>
                  <Typography variant="caption" color="text.secondary">
                    Agreement ID
                  </Typography>
                  <Typography variant="body1" fontWeight="medium">
                    #{proposal.agreement_id}
                  </Typography>
                </Box>

                <Box>
                  <Typography variant="caption" color="text.secondary">
                    Target Value
                  </Typography>
                  <Typography variant="body1" fontWeight="medium">
                    {formatTargetValue(proposal.proposal_type, proposal.target_value)}
                  </Typography>
                </Box>

                <Box>
                  <Typography variant="caption" color="text.secondary">
                    Proposer
                  </Typography>
                  <Typography variant="body1" fontWeight="medium" sx={{ fontFamily: 'monospace', fontSize: '0.85rem' }}>
                    {proposal.proposer}
                  </Typography>
                </Box>

                <Box>
                  <Typography variant="caption" color="text.secondary">
                    Voting Period
                  </Typography>
                  <Typography variant="body2">
                    <strong>Starts:</strong> {new Date(proposal.voting_start).toLocaleString()}
                  </Typography>
                  <Typography variant="body2">
                    <strong>Ends:</strong> {new Date(proposal.voting_end).toLocaleString()}
                  </Typography>
                </Box>

                {proposal.quorum_reached !== undefined && (
                  <Box>
                    <Typography variant="caption" color="text.secondary">
                      Quorum Status
                    </Typography>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                      {proposal.quorum_reached ? (
                        <>
                          <CheckCircleIcon color="success" fontSize="small" />
                          <Typography variant="body1" color="success.main">
                            Quorum Reached ✓
                          </Typography>
                        </>
                      ) : (
                        <>
                          <HowToVoteIcon color="warning" fontSize="small" />
                          <Typography variant="body1" color="warning.main">
                            Awaiting Votes
                          </Typography>
                        </>
                      )}
                    </Box>
                    {!proposal.quorum_reached && proposal.status === 'ACTIVE' && (
                      <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 0.5 }}>
                        Voting is open - cast your vote to help reach quorum
                      </Typography>
                    )}
                    {!proposal.quorum_reached && proposal.status === 'PENDING' && (
                      <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 0.5 }}>
                        Voting will open after the 1-day delay period
                      </Typography>
                    )}
                  </Box>
                )}
              </Box>
            </CardContent>
          </Card>
        </Grid>

        {/* Right Column - Voting Stats */}
        <Grid item xs={12} md={6}>
          <Card elevation={2}>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Voting Statistics
              </Typography>
              <Divider sx={{ mb: 2 }} />

              {/* For Votes */}
              <Box sx={{ mb: 3 }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                  <Typography variant="body2" color="success.main" fontWeight="medium">
                    For
                  </Typography>
                  <Typography variant="body2" fontWeight="medium">
                    {proposal.for_votes} votes ({votePercentages.forPercent.toFixed(1)}%)
                  </Typography>
                </Box>
                <LinearProgress 
                  variant="determinate" 
                  value={votePercentages.forPercent} 
                  color="success"
                  sx={{ height: 8, borderRadius: 1 }}
                />
              </Box>

              {/* Against Votes */}
              <Box sx={{ mb: 3 }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                  <Typography variant="body2" color="error.main" fontWeight="medium">
                    Against
                  </Typography>
                  <Typography variant="body2" fontWeight="medium">
                    {proposal.against_votes} votes ({votePercentages.againstPercent.toFixed(1)}%)
                  </Typography>
                </Box>
                <LinearProgress 
                  variant="determinate" 
                  value={votePercentages.againstPercent} 
                  color="error"
                  sx={{ height: 8, borderRadius: 1 }}
                />
              </Box>

              {/* Abstain Votes */}
              <Box sx={{ mb: 2 }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                  <Typography variant="body2" color="text.secondary" fontWeight="medium">
                    Abstain
                  </Typography>
                  <Typography variant="body2" fontWeight="medium">
                    {proposal.abstain_votes} votes ({votePercentages.abstainPercent.toFixed(1)}%)
                  </Typography>
                </Box>
                <LinearProgress 
                  variant="determinate" 
                  value={votePercentages.abstainPercent} 
                  color="inherit"
                  sx={{ height: 8, borderRadius: 1 }}
                />
              </Box>

              <Divider sx={{ my: 2 }} />

              {/* Total Votes */}
              <Box sx={{ display: 'flex', justifyContent: 'space-between' }}>
                <Typography variant="body1" fontWeight="bold">
                  Total Votes
                </Typography>
                <Typography variant="body1" fontWeight="bold">
                  {proposal.for_votes + proposal.against_votes + proposal.abstain_votes}
                </Typography>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Status Info */}
      {proposal.status === 'EXECUTED' && (
        <Alert severity="success" icon={<CheckCircleIcon />} sx={{ mt: 3 }}>
          This proposal has been executed successfully.
        </Alert>
      )}
      {proposal.status === 'DEFEATED' && (
        <Alert severity="error" icon={<CancelIcon />} sx={{ mt: 3 }}>
          This proposal was defeated and will not be executed.
        </Alert>
      )}
      {proposal.status === 'PENDING' && (
        <Alert severity="info" sx={{ mt: 3 }}>
          Voting has not started yet. Voting will open on {new Date(proposal.voting_start).toLocaleString()}.
        </Alert>
      )}

      {/* Success Message */}
      {voteSuccess && (
        <Alert severity="success" sx={{ mt: 3 }} onClose={() => setVoteSuccess(null)}>
          {voteSuccess}
        </Alert>
      )}

      {/* Voting Power Info */}
      {proposal.status === 'ACTIVE' && (
        <Alert severity="info" sx={{ mt: 3 }}>
          <Typography variant="body2">
            <strong>Your Voting Power:</strong> {votingPower.toLocaleString()} tokens
          </Typography>
          {hasVoted && (
            <Typography variant="body2" color="success.main" sx={{ mt: 1 }}>
              ✓ You have already voted on this proposal
            </Typography>
          )}
          {votingPower === 0 && (
            <Typography variant="body2" color="warning.main" sx={{ mt: 1 }}>
              ⚠ You need tokens to vote on this proposal
            </Typography>
          )}
        </Alert>
      )}

      {/* Vote Dialog */}
      <Dialog open={voteDialogOpen} onClose={() => !voting && setVoteDialogOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <HowToVoteIcon color="primary" />
            Cast Your Vote
          </Box>
        </DialogTitle>
        <DialogContent>
          <Typography variant="body1" paragraph>
            You are about to cast your vote on Proposal #{proposalId}
          </Typography>
          <Typography variant="body2" color="text.secondary" paragraph>
            Your voting power: <strong>{votingPower.toLocaleString()}</strong> tokens
          </Typography>
          <Typography variant="body2" color="text.secondary" paragraph>
            Choose how you want to vote:
          </Typography>
          <Grid container spacing={2}>
            <Grid item xs={12}>
              <Button
                fullWidth
                variant="contained"
                color="success"
                startIcon={<ThumbUpIcon />}
                onClick={() => handleVote(1)}
                disabled={voting}
                size="large"
              >
                {voting ? <CircularProgress size={24} /> : 'Vote For'}
              </Button>
            </Grid>
            <Grid item xs={12}>
              <Button
                fullWidth
                variant="contained"
                color="error"
                startIcon={<ThumbDownIcon />}
                onClick={() => handleVote(0)}
                disabled={voting}
                size="large"
              >
                {voting ? <CircularProgress size={24} /> : 'Vote Against'}
              </Button>
            </Grid>
            <Grid item xs={12}>
              <Button
                fullWidth
                variant="outlined"
                startIcon={<RemoveCircleOutlineIcon />}
                onClick={() => handleVote(2)}
                disabled={voting}
                size="large"
              >
                {voting ? <CircularProgress size={24} /> : 'Abstain'}
              </Button>
            </Grid>
          </Grid>
          <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 2 }}>
            <strong>Note:</strong> You can only vote once per proposal. This action cannot be undone.
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setVoteDialogOpen(false)} disabled={voting}>
            Cancel
          </Button>
        </DialogActions>
      </Dialog>
    </Container>
  );
}

export default GovernanceProposalDetail;

