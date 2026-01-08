/**
 * Voting Interface Component
 * 
 * Displays governance proposal details and allows users to cast votes.
 * Shows voting power, vote distribution, quorum progress, and voting period status.
 */

import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Button,
  ButtonGroup,
  Alert,
  CircularProgress,
  Chip,
  LinearProgress,
  Paper,
  Grid
} from '@mui/material';
import ThumbUpIcon from '@mui/icons-material/ThumbUp';
import ThumbDownIcon from '@mui/icons-material/ThumbDown';
import RemoveCircleIcon from '@mui/icons-material/RemoveCircle';

const VotingInterface = ({ proposal }) => {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [userVotingPower, setUserVotingPower] = useState(0);
  const [hasVoted, setHasVoted] = useState(false);

  // Calculate voting metrics
  const totalVotes = (proposal?.for_votes || 0) + (proposal?.against_votes || 0) + (proposal?.abstain_votes || 0);
  const quorumProgress = proposal?.quorum_required > 0 
    ? (totalVotes / proposal.quorum_required) * 100 
    : 0;
  const forPercentage = totalVotes > 0 
    ? ((proposal?.for_votes || 0) / totalVotes) * 100 
    : 0;
  const againstPercentage = totalVotes > 0
    ? ((proposal?.against_votes || 0) / totalVotes) * 100
    : 0;
  const abstainPercentage = totalVotes > 0
    ? ((proposal?.abstain_votes || 0) / totalVotes) * 100
    : 0;

  // Check voting period status
  const now = new Date();
  const votingStart = new Date(proposal?.voting_start);
  const votingEnd = new Date(proposal?.voting_end);
  const isVotingActive = now >= votingStart && now <= votingEnd;
  const votingEnded = now > votingEnd;
  const votingNotStarted = now < votingStart;

  // Get time remaining or time since ended
  const getTimeStatus = () => {
    if (votingNotStarted) {
      const hoursUntilStart = Math.floor((votingStart - now) / (1000 * 60 * 60));
      return `Voting starts in ${hoursUntilStart} hours`;
    } else if (isVotingActive) {
      const hoursRemaining = Math.floor((votingEnd - now) / (1000 * 60 * 60));
      const daysRemaining = Math.floor(hoursRemaining / 24);
      return `${daysRemaining} days, ${hoursRemaining % 24} hours remaining`;
    } else {
      const hoursAgo = Math.floor((now - votingEnd) / (1000 * 60 * 60));
      return `Voting ended ${hoursAgo} hours ago`;
    }
  };

  useEffect(() => {
    // Fetch user's voting power and whether they've voted
    fetchVotingStatus();
  }, [proposal]);

  const fetchVotingStatus = async () => {
    try {
      // Placeholder - implement actual API calls
      // const votingPower = await getVotingPower(userAddress, proposal.agreement_id);
      // setUserVotingPower(votingPower);
      
      // const voted = await hasVoted(proposal.proposal_id, userAddress);
      // setHasVoted(voted);

      // Mock data
      setUserVotingPower(50000);
      setHasVoted(false);
    } catch (err) {
      console.error('Error fetching voting status:', err);
    }
  };

  const handleVote = async (support) => {
    // Validate
    if (userVotingPower === 0) {
      setError('You have no voting power for this proposal');
      return;
    }

    if (!isVotingActive) {
      setError('Voting period is not active');
      return;
    }

    if (hasVoted) {
      setError('You have already voted on this proposal');
      return;
    }

    setLoading(true);
    setError(null);
    setSuccess(null);

    try {
      // Call API to cast vote
      console.log(`Casting vote: ${support} on proposal ${proposal.proposal_id}`);
      // const response = await castVote({
      //   proposal_id: proposal.proposal_id,
      //   support: support,
      //   token_standard: 'ERC721'
      // });

      // Mock response
      const supportLabels = { 0: 'Against', 1: 'For', 2: 'Abstain' };
      setSuccess(`Vote cast successfully: ${supportLabels[support]} with ${userVotingPower.toLocaleString()} votes`);
      setHasVoted(true);

      // Refresh proposal data
      // await refreshProposal();

    } catch (err) {
      console.error('Error casting vote:', err);
      setError(err.detail || err.message || 'Failed to cast vote');
    } finally {
      setLoading(false);
    }
  };

  if (!proposal) {
    return <Typography>Loading proposal...</Typography>;
  }

  return (
    <Paper elevation={2} sx={{ p: 3, mt: 3 }}>
      <Typography variant="h6" gutterBottom>
        Cast Your Vote
      </Typography>

      {/* Voting Power Display */}
      <Alert severity="info" sx={{ mb: 2 }}>
        <Typography variant="body2">
          <strong>Your Voting Power:</strong> {userVotingPower.toLocaleString()} tokens
        </Typography>
      </Alert>

      {/* Voting Period Status */}
      <Alert 
        severity={isVotingActive ? 'success' : votingNotStarted ? 'warning' : 'info'} 
        sx={{ mb: 2 }}
      >
        <Typography variant="body2">
          <strong>Voting Status:</strong> {getTimeStatus()}
        </Typography>
        <Typography variant="caption" display="block">
          Period: {votingStart.toLocaleString()} - {votingEnd.toLocaleString()}
        </Typography>
      </Alert>

      {/* Quorum Progress */}
      <Box sx={{ mb: 3 }}>
        <Typography variant="body2" gutterBottom>
          <strong>Quorum Progress:</strong> {quorumProgress.toFixed(1)}%
        </Typography>
        <LinearProgress 
          variant="determinate" 
          value={Math.min(quorumProgress, 100)} 
          sx={{ height: 10, borderRadius: 5 }}
        />
        <Typography variant="caption" color="textSecondary">
          {totalVotes.toLocaleString()} / {proposal.quorum_required?.toLocaleString() || '0'} votes 
          ({quorumProgress >= 100 ? 'Quorum reached ✓' : 'Quorum not reached'})
        </Typography>
      </Box>

      {/* Vote Distribution */}
      <Box sx={{ mb: 3 }}>
        <Typography variant="body2" gutterBottom>
          <strong>Current Votes:</strong>
        </Typography>
        <Grid container spacing={1}>
          <Grid item xs={4}>
            <Chip
              icon={<ThumbUpIcon />}
              label={`For: ${(proposal.for_votes || 0).toLocaleString()} (${forPercentage.toFixed(1)}%)`}
              color="success"
              sx={{ width: '100%' }}
            />
          </Grid>
          <Grid item xs={4}>
            <Chip
              icon={<ThumbDownIcon />}
              label={`Against: ${(proposal.against_votes || 0).toLocaleString()} (${againstPercentage.toFixed(1)}%)`}
              color="error"
              sx={{ width: '100%' }}
            />
          </Grid>
          <Grid item xs={4}>
            <Chip
              icon={<RemoveCircleIcon />}
              label={`Abstain: ${(proposal.abstain_votes || 0).toLocaleString()} (${abstainPercentage.toFixed(1)}%)`}
              color="default"
              sx={{ width: '100%' }}
            />
          </Grid>
        </Grid>
      </Box>

      {/* Voting Buttons */}
      {!hasVoted && (
        <ButtonGroup 
          variant="contained" 
          fullWidth 
          disabled={loading || !isVotingActive || userVotingPower === 0}
          sx={{ mb: 2 }}
        >
          <Button
            color="success"
            startIcon={<ThumbUpIcon />}
            onClick={() => handleVote(1)}
          >
            Vote For
          </Button>
          <Button
            color="error"
            startIcon={<ThumbDownIcon />}
            onClick={() => handleVote(0)}
          >
            Vote Against
          </Button>
          <Button
            color="inherit"
            startIcon={<RemoveCircleIcon />}
            onClick={() => handleVote(2)}
          >
            Abstain
          </Button>
        </ButtonGroup>
      )}

      {/* Status Messages */}
      {hasVoted && (
        <Alert severity="info" sx={{ mb: 2 }}>
          You have already voted on this proposal
        </Alert>
      )}

      {loading && (
        <Box display="flex" justifyContent="center" alignItems="center" sx={{ my: 2 }}>
          <CircularProgress size={24} sx={{ mr: 2 }} />
          <Typography>Submitting vote...</Typography>
        </Box>
      )}

      {success && (
        <Alert severity="success" sx={{ mb: 2 }}>
          {success}
        </Alert>
      )}

      {error && (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      )}

      {/* Help Text */}
      {userVotingPower === 0 && (
        <Alert severity="warning">
          You need to hold tokens for this agreement to vote
        </Alert>
      )}
    </Paper>
  );
};

export default VotingInterface;

