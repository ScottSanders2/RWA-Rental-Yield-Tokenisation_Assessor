/**
 * Governance Proposal Detail Screen (React Native)
 * Mobile-optimized voting interface with proposal details.
 * Includes user profile picker for multi-voter governance testing.
 */

import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  Alert,
  RefreshControl,
  Platform
} from 'react-native';
import { getProposal, castVote, getVotingPower, executeProposal, checkVoteStatus } from '../services/apiClient.native';
import UserProfilePicker from '../components/UserProfilePicker.native';
import axios from 'axios';

const GovernanceDetail = ({ route, navigation }) => {
  const { proposalId } = route.params;
  const [proposal, setProposal] = useState(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [votingPower, setVotingPower] = useState(0);
  const [hasVoted, setHasVoted] = useState(false);
  const [voting, setVoting] = useState(false);
  const [currentProfile, setCurrentProfile] = useState(null);

  useEffect(() => {
    const initializeProposal = async () => {
      await fetchProposalData();
    };
    initializeProposal();
  }, [proposalId]);

  // Reload voting status and power when profile changes
  useEffect(() => {
    if (currentProfile && proposal) {
      loadVotedStatus();
      fetchVotingPower();
    }
  }, [currentProfile, proposal?.agreement_id]);

  const loadVotedStatus = async () => {
    if (!currentProfile) return;
    
    try {
      // Call backend API to check if user has voted (uses current profile's wallet)
      const { data } = await checkVoteStatus(proposalId, currentProfile.wallet_address);
      
      if (data.has_voted) {
        setHasVoted(true);
        const voteLabels = {0: 'Against', 1: 'For', 2: 'Abstain'};
        console.log(`✅ ${currentProfile.display_name} has already voted on proposal ${proposalId}: ${voteLabels[data.support]}`);
      } else {
        setHasVoted(false);
        console.log(`ℹ️ ${currentProfile.display_name} has not voted on proposal ${proposalId} yet`);
      }
    } catch (err) {
      console.error(`❌ Error loading voted status for ${currentProfile.display_name}:`, err.message || err);
      // Don't set hasVoted on error - allow voting attempt (backend will enforce)
    }
  };

  const fetchVotingPower = async () => {
    if (!currentProfile || !proposal) return;
    
    const API_BASE_URL = Platform.OS === 'ios' ? 'http://localhost:8000' : 'http://10.0.2.2:8000';
    
    try {
      const response = await axios.get(
        `${API_BASE_URL}/users/profiles/${currentProfile.wallet_address}/voting-power/${proposal.agreement_id}`
      );
      setVotingPower(response.data.voting_power);
      console.log(`📊 ${currentProfile.display_name} voting power: ${response.data.voting_power.toLocaleString()} tokens (${response.data.percentage}%)`);
    } catch (err) {
      console.error(`❌ Error fetching voting power for ${currentProfile.display_name}:`, err.message || err);
      setVotingPower(50000); // Fallback
    }
  };

  const handleProfileChange = (profile) => {
    console.log('👤 Profile changed to:', profile.display_name);
    setCurrentProfile(profile);
  };

  const fetchProposalData = async () => {
    try {
      setLoading(true);
      
      // Fetch real proposal data from backend
      const { data: proposalData } = await getProposal(proposalId);
      
      setProposal(proposalData);
      
      // Voting power will be fetched by useEffect when currentProfile and proposal are set
      // Don't fetch voting power here - we need currentProfile.wallet_address
      
      // Note: hasVoted status is managed by loadVotedStatus() function
      // Do not reset it here to avoid race conditions
    } catch (err) {
      console.error('Failed to load proposal from backend, using mock data:', err);
      
      // Fallback to mock data if backend unavailable
      const mockProposal = {
        proposal_id: proposalId,
        proposer: '0x1234...5678',
        agreement_id: 1,
        proposal_type: 'ROI_ADJUSTMENT',
        target_value: 1260,
        description: 'Increase ROI from 12% to 12.6% to account for market changes (Mock Data - Backend Unavailable)',
        voting_start: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000),
        voting_end: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000),
        for_votes: 300000,
        against_votes: 150000,
        abstain_votes: 50000,
        executed: false,
        defeated: false,
        quorum_reached: true,
        status: 'ACTIVE' // Mock as ACTIVE so voting works in offline mode
      };
      setProposal(mockProposal);
      // Voting power will be fetched by fetchVotingPower() when profile is selected
      // Note: hasVoted status is managed by loadVotedStatus() function
    } finally {
      setLoading(false);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await fetchProposalData();
    await loadVotedStatus(); // Reload vote status after refresh
    await fetchVotingPower(); // Reload voting power after refresh
    setRefreshing(false);
  };

  const handleVote = async (support) => {
    if (!currentProfile) {
      Alert.alert('Error', 'Please select a user profile to vote');
      return;
    }

    if (votingPower === 0) {
      Alert.alert('Error', `${currentProfile.display_name} has no voting power for this proposal`);
      return;
    }

    if (hasVoted) {
      Alert.alert('Error', `${currentProfile.display_name} has already voted on this proposal`);
      return;
    }

    const now = new Date();
    if (now < new Date(proposal.voting_start) || now > new Date(proposal.voting_end)) {
      Alert.alert('Error', 'Voting period is not active');
      return;
    }

    const supportLabels = { 0: 'Against', 1: 'For', 2: 'Abstain' };

    Alert.alert(
      'Confirm Vote',
      `Cast ${supportLabels[support]} vote as ${currentProfile.display_name} with ${votingPower.toLocaleString()} tokens?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Confirm',
          onPress: async () => {
            setVoting(true);
            try {
              await castVote(
                { proposal_id: proposalId, support, token_standard: 'ERC721' },
                currentProfile.wallet_address
              );
              // Backend now records vote in database - no client-side storage needed
              setHasVoted(true);
              Alert.alert('Success', `Vote cast: ${supportLabels[support]}`);
              // Refresh proposal data after voting
              await fetchProposalData();
            } catch (err) {
              Alert.alert('Error', err.message || 'Failed to cast vote');
            } finally {
              setVoting(false);
            }
          }
        }
      ]
    );
  };

  const handleExecute = async () => {
    Alert.alert(
      'Execute Proposal',
      'Execute this proposal? This action cannot be undone.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Execute',
          onPress: async () => {
            try {
              await executeProposal(proposalId);
              Alert.alert('Success', 'Proposal executed successfully');
              await fetchProposalData();
            } catch (err) {
              Alert.alert('Error', err.message || 'Failed to execute proposal');
            }
          }
        }
      ]
    );
  };

  if (loading) {
    return (
      <View style={styles.centerContainer}>
        <ActivityIndicator size="large" color="#2196F3" />
        <Text style={styles.loadingText}>Loading proposal...</Text>
      </View>
    );
  }

  if (!proposal) {
    return (
      <View style={styles.centerContainer}>
        <Text style={styles.errorText}>Proposal not found</Text>
      </View>
    );
  }

  const totalVotes = proposal.for_votes + proposal.against_votes + proposal.abstain_votes;
  // Use backend quorum_required instead of hardcoded mock value
  const quorumRequired = proposal.quorum_required || 100000;
  const quorumProgress = quorumRequired > 0 ? (totalVotes / quorumRequired) * 100 : 0;
  const forPercentage = totalVotes > 0 ? (proposal.for_votes / totalVotes) * 100 : 0;
  const againstPercentage = totalVotes > 0 ? (proposal.against_votes / totalVotes) * 100 : 0;

  const now = new Date();
  const votingStart = new Date(proposal.voting_start);
  const votingEnd = new Date(proposal.voting_end);
  const isVotingActive = now >= votingStart && now <= votingEnd;
  const votingEnded = now > votingEnd;
  
  // Check if proposal is in PENDING state (before 1-day delay)
  const isPending = proposal.status === 'PENDING' || (!isVotingActive && !votingEnded);

  const getStatusColor = () => {
    if (proposal.executed) return '#4CAF50';
    if (proposal.defeated) return '#F44336';
    if (isVotingActive) return '#2196F3';
    return '#FF9800';
  };

  const getStatusText = () => {
    if (proposal.executed) return 'Executed';
    if (proposal.defeated) return 'Defeated';
    if (isVotingActive) return 'Active';
    if (votingEnded) return 'Pending Execution';
    return 'Pending';
  };

  return (
    <ScrollView
      style={styles.container}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
    >
      {/* User Profile Picker for Multi-Voter Testing */}
      <UserProfilePicker
        onProfileChange={handleProfileChange}
        currentProfile={currentProfile}
      />

      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Proposal #{proposal.proposal_id}</Text>
        <View style={[styles.statusBadge, { backgroundColor: getStatusColor() }]}>
          <Text style={styles.statusText}>{getStatusText()}</Text>
        </View>
      </View>
      
      {/* Pending Status Warning */}
      {isPending && (
        <View style={styles.warningBox}>
          <Text style={styles.warningIcon}>⏱️</Text>
          <View style={styles.warningContent}>
            <Text style={styles.warningTitle}>Voting Not Started</Text>
            <Text style={styles.warningText}>
              This proposal is in the 1-day delay period. Voting will open on{' '}
              {votingStart.toLocaleDateString()} at {votingStart.toLocaleTimeString()}.
            </Text>
          </View>
        </View>
      )}

      {/* Proposal Details */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Proposal Details</Text>
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Type:</Text>
          <Text style={styles.detailValue}>{proposal.proposal_type.replace('_', ' ')}</Text>
        </View>
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Agreement ID:</Text>
          <Text style={styles.detailValue}>{proposal.agreement_id}</Text>
        </View>
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Proposer:</Text>
          <Text style={styles.detailValue} numberOfLines={1} ellipsizeMode="middle">
            {proposal.proposer}
          </Text>
        </View>
        <Text style={styles.description}>{proposal.description}</Text>
      </View>

      {/* Voting Power */}
      <View style={[styles.section, styles.infoBanner]}>
        <Text style={styles.infoBannerText}>
          Your Voting Power: <Text style={styles.bold}>{votingPower.toLocaleString()}</Text> tokens
        </Text>
      </View>

      {/* Voting Period */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Voting Period</Text>
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Starts:</Text>
          <Text style={styles.detailValue}>{votingStart.toLocaleDateString()}</Text>
        </View>
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Ends:</Text>
          <Text style={styles.detailValue}>{votingEnd.toLocaleDateString()}</Text>
        </View>
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Status:</Text>
          <Text style={[styles.detailValue, { color: isVotingActive ? '#4CAF50' : '#F44336' }]}>
            {isVotingActive ? 'Active' : votingEnded ? 'Ended' : 'Not Started'}
          </Text>
        </View>
      </View>

      {/* Quorum Progress */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Quorum Progress: {quorumProgress.toFixed(1)}%</Text>
        <View style={styles.progressBarContainer}>
          <View style={[styles.progressBar, { width: `${Math.min(quorumProgress, 100)}%` }]} />
        </View>
        <Text style={styles.helper}>
          {totalVotes.toLocaleString()} / {quorumRequired.toLocaleString()} votes
        </Text>
      </View>

      {/* Vote Distribution */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Vote Distribution</Text>
        <View style={styles.voteRow}>
          <View style={[styles.voteBox, styles.voteBoxFor]}>
            <Text style={styles.voteLabel}>For</Text>
            <Text style={styles.voteValue}>{proposal.for_votes.toLocaleString()}</Text>
            <Text style={styles.votePercent}>{forPercentage.toFixed(1)}%</Text>
          </View>
          <View style={[styles.voteBox, styles.voteBoxAgainst]}>
            <Text style={styles.voteLabel}>Against</Text>
            <Text style={styles.voteValue}>{proposal.against_votes.toLocaleString()}</Text>
            <Text style={styles.votePercent}>{againstPercentage.toFixed(1)}%</Text>
          </View>
        </View>
        <View style={[styles.voteBox, styles.voteBoxAbstain]}>
          <Text style={styles.voteLabel}>Abstain</Text>
          <Text style={styles.voteValue}>{proposal.abstain_votes.toLocaleString()}</Text>
        </View>
      </View>

      {/* PENDING Status Alert */}
      {!isVotingActive && !votingEnded && (
        <View style={styles.alertWarning}>
          <Text style={styles.alertText}>⏳ Voting Not Started</Text>
          <Text style={styles.alertSubText}>
            Voting will open on {votingStart.toLocaleString()}
          </Text>
          <Text style={styles.alertSubText}>
            (1-day delay period is in effect)
          </Text>
        </View>
      )}

      {/* Voting Buttons */}
      {!hasVoted && isVotingActive && votingPower > 0 && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Cast Your Vote</Text>
          <View style={styles.votingButtons}>
            <TouchableOpacity
              style={[styles.voteButton, styles.voteButtonFor]}
              onPress={() => handleVote(1)}
              disabled={voting}
            >
              <Text style={styles.voteButtonText}>Vote For</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.voteButton, styles.voteButtonAgainst]}
              onPress={() => handleVote(0)}
              disabled={voting}
            >
              <Text style={styles.voteButtonText}>Vote Against</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.voteButton, styles.voteButtonAbstain]}
              onPress={() => handleVote(2)}
              disabled={voting}
            >
              <Text style={styles.voteButtonText}>Abstain</Text>
            </TouchableOpacity>
          </View>
        </View>
      )}

      {/* Status Messages */}
      {hasVoted && (
        <View style={styles.alertInfo}>
          <Text style={styles.alertText}>✓ You have already voted on this proposal</Text>
        </View>
      )}

      {votingPower === 0 && isVotingActive && (
        <View style={styles.alertWarning}>
          <Text style={styles.alertText}>⚠ You need tokens to vote on this proposal</Text>
        </View>
      )}

      {/* Execute Button */}
      {votingEnded && !proposal.executed && !proposal.defeated && (
        <TouchableOpacity style={styles.executeButton} onPress={handleExecute}>
          <Text style={styles.executeButtonText}>Execute Proposal</Text>
        </TouchableOpacity>
      )}
      
      {/* Navigation Buttons */}
      <View style={styles.navigationButtons}>
        <TouchableOpacity 
          style={[styles.navButton, styles.navButtonDashboard]} 
          onPress={() => navigation.navigate('Governance')}
        >
          <Text style={styles.navButtonText}>← Back to Dashboard</Text>
        </TouchableOpacity>
      </View>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  centerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f5f5f5',
  },
  loadingText: {
    marginTop: 10,
    fontSize: 16,
    color: '#666',
  },
  errorText: {
    fontSize: 16,
    color: '#F44336',
  },
  header: {
    padding: 20,
    backgroundColor: '#2196F3',
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#fff',
    flex: 1,
  },
  statusBadge: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 16,
  },
  statusText: {
    color: '#fff',
    fontWeight: 'bold',
    fontSize: 12,
  },
  section: {
    margin: 16,
    padding: 16,
    backgroundColor: '#fff',
    borderRadius: 8,
    elevation: 2,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 12,
  },
  detailRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 8,
  },
  detailLabel: {
    fontSize: 14,
    color: '#666',
  },
  detailValue: {
    fontSize: 14,
    fontWeight: 'bold',
    color: '#333',
    flex: 1,
    textAlign: 'right',
  },
  description: {
    fontSize: 14,
    color: '#666',
    marginTop: 12,
    lineHeight: 20,
  },
  infoBanner: {
    backgroundColor: '#E3F2FD',
  },
  infoBannerText: {
    fontSize: 16,
    color: '#1976D2',
  },
  bold: {
    fontWeight: 'bold',
  },
  progressBarContainer: {
    height: 20,
    backgroundColor: '#E0E0E0',
    borderRadius: 10,
    overflow: 'hidden',
    marginBottom: 8,
  },
  progressBar: {
    height: '100%',
    backgroundColor: '#4CAF50',
  },
  helper: {
    fontSize: 12,
    color: '#666',
  },
  voteRow: {
    flexDirection: 'row',
    gap: 8,
    marginBottom: 8,
  },
  voteBox: {
    flex: 1,
    padding: 12,
    borderRadius: 8,
    alignItems: 'center',
  },
  voteBoxFor: {
    backgroundColor: '#E8F5E9',
  },
  voteBoxAgainst: {
    backgroundColor: '#FFEBEE',
  },
  voteBoxAbstain: {
    backgroundColor: '#F5F5F5',
  },
  voteLabel: {
    fontSize: 12,
    color: '#666',
    marginBottom: 4,
  },
  voteValue: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
  },
  votePercent: {
    fontSize: 12,
    color: '#999',
    marginTop: 2,
  },
  votingButtons: {
    gap: 8,
  },
  voteButton: {
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
  },
  voteButtonFor: {
    backgroundColor: '#4CAF50',
  },
  voteButtonAgainst: {
    backgroundColor: '#F44336',
  },
  voteButtonAbstain: {
    backgroundColor: '#9E9E9E',
  },
  voteButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
  },
  executeButton: {
    margin: 16,
    padding: 16,
    backgroundColor: '#2196F3',
    borderRadius: 8,
    alignItems: 'center',
  },
  executeButtonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
  },
  alertInfo: {
    margin: 16,
    padding: 12,
    backgroundColor: '#E3F2FD',
    borderRadius: 8,
  },
  alertWarning: {
    margin: 16,
    padding: 12,
    backgroundColor: '#FFF3E0',
    borderRadius: 8,
  },
  alertText: {
    fontSize: 14,
    color: '#333',
    fontWeight: 'bold',
  },
  alertSubText: {
    fontSize: 12,
    color: '#666',
    marginTop: 4,
  },
  warningBox: {
    margin: 16,
    padding: 16,
    backgroundColor: '#FFF3E0',
    borderRadius: 8,
    borderLeftWidth: 4,
    borderLeftColor: '#FF9800',
    flexDirection: 'row',
    alignItems: 'flex-start',
  },
  warningIcon: {
    fontSize: 24,
    marginRight: 12,
  },
  warningContent: {
    flex: 1,
  },
  warningTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 4,
  },
  warningText: {
    fontSize: 14,
    color: '#666',
    lineHeight: 20,
  },
  navigationButtons: {
    padding: 16,
    paddingBottom: 32,
  },
  navButton: {
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
    marginBottom: 12,
  },
  navButtonDashboard: {
    backgroundColor: '#607D8B',
  },
  navButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
  },
});

export default GovernanceDetail;


