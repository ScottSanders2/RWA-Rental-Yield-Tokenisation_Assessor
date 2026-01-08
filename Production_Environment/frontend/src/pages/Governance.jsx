/**
 * Governance Dashboard Page
 * 
 * Displays governance overview with:
 * - Active/executed/defeated proposals
 * - User's voting power
 * - Quick actions (create proposal, view proposals)
 * - Token standard display
 */

import React, { useState, useEffect } from 'react';
import {
  Container,
  Typography,
  Box,
  Grid,
  Card,
  CardContent,
  CardActions,
  Button,
  Tabs,
  Tab,
  Alert,
  CircularProgress,
  Chip,
  Paper,
  List,
  ListItem,
  ListItemText,
  Divider
} from '@mui/material';
import {
  HowToVote as HowToVoteIcon,
  AddCircle as AddCircleIcon,
  List as ListIcon,
  CheckCircle as CheckCircleIcon,
  Cancel as CancelIcon
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { getProposals } from '../services/apiClient';

const Governance = () => {
  const navigate = useNavigate();
  const [proposals, setProposals] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [activeTab, setActiveTab] = useState(0); // 0=Active, 1=Executed, 2=Defeated
  const proposalsListRef = React.useRef(null); // Reference for scrolling to proposals

  // Placeholder - replace with actual context
  const tokenStandard = 'ERC721';
  const userVotingPower = 50000;

  useEffect(() => {
    fetchProposals();
  }, []);

  const fetchProposals = async () => {
    try {
      setLoading(true);
      
      // Fetch real proposals from API using apiClient (routes through NGINX proxy in production)
      const response = await getProposals();
      setProposals(response.data || []);
    } catch (err) {
      console.error('Error fetching proposals:', err);
      setError('Failed to load proposals. Ensure backend is running.');
      setProposals([]); // Set empty array on error
    } finally {
      setLoading(false);
    }
  };

  const handleTabChange = (event, newValue) => {
    setActiveTab(newValue);
  };

  const filterProposals = () => {
    const now = new Date();
    
    switch (activeTab) {
      case 0: // Active
        return proposals.filter(p => 
          !p.executed && !p.defeated && new Date(p.voting_end) > now
        );
      case 1: // Executed
        return proposals.filter(p => p.executed);
      case 2: // Defeated
        return proposals.filter(p => p.defeated);
      default:
        return proposals;
    }
  };

  const filteredProposals = filterProposals();

  const getProposalTypeLabel = (type) => {
    const labels = {
      'ROI_ADJUSTMENT': 'ROI Adjustment',
      'RESERVE_ALLOCATION': 'Reserve Allocation',
      'RESERVE_WITHDRAWAL': 'Reserve Withdrawal',
      'PARAMETER_UPDATE': 'Parameter Update'
    };
    return labels[type] || type;
  };

  const getStatusChip = (proposal) => {
    const now = new Date();
    const votingEnd = new Date(proposal.voting_end);

    if (proposal.executed) {
      return <Chip label="Executed" color="success" size="small" icon={<CheckCircleIcon />} />;
    }
    if (proposal.defeated) {
      return <Chip label="Defeated" color="error" size="small" icon={<CancelIcon />} />;
    }
    if (votingEnd > now) {
      return <Chip label="Active" color="primary" size="small" />;
    }
    return <Chip label="Pending Execution" color="warning" size="small" />;
  };

  if (loading) {
    return (
      <Container maxWidth="lg" sx={{ mt: 4, mb: 4, textAlign: 'center' }}>
        <CircularProgress />
        <Typography variant="h6" sx={{ mt: 2 }}>Loading governance data...</Typography>
      </Container>
    );
  }

  return (
    <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
      <Typography variant="h4" gutterBottom>
        Governance Dashboard
      </Typography>

      <Alert severity="info" sx={{ mb: 3 }}>
        <strong>Token Standard:</strong> {tokenStandard} | 
        <strong> Voting Mechanism:</strong> 1 token = 1 vote (token-weighted voting) |
        <strong> Your Total Voting Power:</strong> {userVotingPower.toLocaleString()} tokens
      </Alert>

      {error && (
        <Alert severity="error" sx={{ mb: 3 }}>
          {error}
        </Alert>
      )}

      {/* Quick Actions */}
      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} md={4}>
          <Card elevation={3}>
            <CardContent>
              <HowToVoteIcon color="primary" sx={{ fontSize: 40, mb: 1 }} />
              <Typography variant="h6" gutterBottom>
                Create Proposal
              </Typography>
              <Typography variant="body2" color="textSecondary">
                Submit a governance proposal for ROI adjustments, reserve management, or parameter updates
              </Typography>
            </CardContent>
            <CardActions>
              <Button 
                size="small" 
                color="primary"
                startIcon={<AddCircleIcon />}
                onClick={() => navigate('/governance/create')}
              >
                Create Proposal
              </Button>
            </CardActions>
          </Card>
        </Grid>

        <Grid item xs={12} md={4}>
          <Card elevation={3}>
            <CardContent>
              <ListIcon color="primary" sx={{ fontSize: 40, mb: 1 }} />
              <Typography variant="h6" gutterBottom>
                Active Proposals
              </Typography>
              <Typography variant="h3" color="primary">
                {proposals.filter(p => !p.executed && !p.defeated && new Date(p.voting_end) > new Date()).length}
              </Typography>
              <Typography variant="body2" color="textSecondary">
                Currently in voting period
              </Typography>
            </CardContent>
            <CardActions>
              <Button 
                size="small" 
                color="primary"
                onClick={() => {
                  setActiveTab(0);
                  // Scroll to proposals list
                  proposalsListRef.current?.scrollIntoView({ 
                    behavior: 'smooth', 
                    block: 'start' 
                  });
                }}
              >
                View Active
              </Button>
            </CardActions>
          </Card>
        </Grid>

        <Grid item xs={12} md={4}>
          <Card elevation={3}>
            <CardContent>
              <CheckCircleIcon color="success" sx={{ fontSize: 40, mb: 1 }} />
              <Typography variant="h6" gutterBottom>
                Your Voting Power
              </Typography>
              <Typography variant="h3" color="success">
                {userVotingPower.toLocaleString()}
              </Typography>
              <Typography variant="body2" color="textSecondary">
                Tokens across all agreements
              </Typography>
            </CardContent>
            <CardActions>
              <Button 
                size="small" 
                color="primary"
                onClick={() => navigate('/yield-agreements')}
              >
                View Agreements
              </Button>
            </CardActions>
          </Card>
        </Grid>
      </Grid>

      {/* Proposals List with Tabs */}
      <Paper ref={proposalsListRef} elevation={2} sx={{ p: 3 }}>
        <Tabs value={activeTab} onChange={handleTabChange} sx={{ mb: 3 }}>
          <Tab label={`Active (${proposals.filter(p => !p.executed && !p.defeated && new Date(p.voting_end) > new Date()).length})`} />
          <Tab label={`Executed (${proposals.filter(p => p.executed).length})`} />
          <Tab label={`Defeated (${proposals.filter(p => p.defeated).length})`} />
        </Tabs>

        {filteredProposals.length === 0 ? (
          <Alert severity="info">
            No proposals in this category
          </Alert>
        ) : (
          <List>
            {filteredProposals.map((proposal, index) => (
              <React.Fragment key={proposal.proposal_id}>
                <ListItem
                  alignItems="flex-start"
                  sx={{ 
                    cursor: 'pointer',
                    '&:hover': { bgcolor: 'action.hover' }
                  }}
                  onClick={() => navigate(`/governance/proposals/${proposal.proposal_id}`)}
                >
                  <ListItemText
                    primary={
                      <Box display="flex" alignItems="center" gap={1}>
                        <Typography variant="h6">
                          Proposal #{proposal.proposal_id}
                        </Typography>
                        {getStatusChip(proposal)}
                        <Chip 
                          label={getProposalTypeLabel(proposal.proposal_type)} 
                          size="small" 
                          variant="outlined"
                        />
                      </Box>
                    }
                    secondary={
                      <>
                        <Typography variant="body2" color="textPrimary" gutterBottom>
                          {proposal.description}
                        </Typography>
                        <Typography variant="caption" color="textSecondary" display="block">
                          Agreement ID: {proposal.agreement_id} | 
                          Voting ends: {new Date(proposal.voting_end).toLocaleDateString()}
                        </Typography>
                        <Box display="flex" gap={2} mt={1}>
                          <Chip 
                            label={`For: ${proposal.for_votes.toLocaleString()}`} 
                            size="small" 
                            color="success"
                          />
                          <Chip 
                            label={`Against: ${proposal.against_votes.toLocaleString()}`} 
                            size="small" 
                            color="error"
                          />
                          <Chip 
                            label={`Abstain: ${proposal.abstain_votes.toLocaleString()}`} 
                            size="small"
                          />
                        </Box>
                      </>
                    }
                  />
                  <Button
                    variant="outlined"
                    size="small"
                    onClick={(e) => {
                      e.stopPropagation();
                      navigate(`/governance/proposals/${proposal.proposal_id}`);
                    }}
                  >
                    View Details
                  </Button>
                </ListItem>
                {index < filteredProposals.length - 1 && <Divider />}
              </React.Fragment>
            ))}
          </List>
        )}
      </Paper>

      {/* Help Section */}
      <Paper elevation={1} sx={{ p: 3, mt: 3 }}>
        <Typography variant="h6" gutterBottom>
          Governance Help
        </Typography>
        <Typography variant="body2" paragraph>
          <strong>How Governance Works:</strong>
        </Typography>
        <Typography variant="body2" component="div">
          <ul>
            <li>Token holders can create proposals to adjust ROI, allocate reserves, or modify parameters</li>
            <li>Minimum 1% of token supply required to create a proposal (proposal threshold)</li>
            <li>Voting opens 1 day after proposal creation and lasts 7 days</li>
            <li>Minimum 10% of token supply must participate (quorum requirement)</li>
            <li>Simple majority wins (For votes &gt; Against votes)</li>
            <li>Abstain votes count toward quorum but not toward majority</li>
            <li>Successful proposals are executed automatically after voting ends</li>
          </ul>
        </Typography>
      </Paper>
    </Container>
  );
};

export default Governance;

