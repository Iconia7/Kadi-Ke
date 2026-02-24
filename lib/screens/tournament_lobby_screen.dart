import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vps_game_service.dart';
import '../services/custom_auth_service.dart';
import '../models/tournament_model.dart';
import '../widgets/custom_toast.dart';
import '../services/progression_service.dart';
import 'tournament_screen.dart';

class TournamentLobbyScreen extends StatefulWidget {
  const TournamentLobbyScreen({super.key});

  @override
  _TournamentLobbyScreenState createState() => _TournamentLobbyScreenState();
}

class _TournamentLobbyScreenState extends State<TournamentLobbyScreen> {
  final TextEditingController _joinCodeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController(text: "My Tournament");
  
  String _gameType = 'kadi';
  int _maxPlayers = 8;
  int _entryFee = 100;
  
  bool _isCreating = false;
  List<Map<String, dynamic>> _publicTournaments = [];
  bool _isLoadingPublic = false;

  @override
  void initState() {
    super.initState();
    _fetchPublicTournaments();
  }

  Future<void> _fetchPublicTournaments() async {
    setState(() => _isLoadingPublic = true);
    try {
      final list = await VPSGameService().getActiveTournaments();
      if (mounted) {
        setState(() {
          _publicTournaments = list;
          _isLoadingPublic = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPublic = false);
        print("Error fetching public tournaments: $e");
      }
    }
  }

  void _joinTournamentByData(Map<String, dynamic> tData) async {
     String code = tData['id'];
     Tournament tournament = Tournament.fromJson(tData);
     
     setState(() => _isCreating = true); 
     
     try {
        // Attempt to join on server
        await VPSGameService().joinTournament(code);
        if (!mounted) return;

        // Check fee and deduct
        if (tournament.entryFee > 0) {
           int balance = ProgressionService().getCoins();
           if (balance < tournament.entryFee) {
              CustomToast.show(context, "Joined! Entry fee: ${tournament.entryFee} coins.", isError: false);
              bool success = await ProgressionService().spendCoins(tournament.entryFee);
              if (!success) {
                 CustomToast.show(context, "Warning: Insufficient coins.", isError: true);
              }
           } else {
              await ProgressionService().spendCoins(tournament.entryFee);
           }
        }

        Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => TournamentScreen(
              tournamentId: code, 
              isHost: false,
              initialTournament: tournament,
          ))
        );
     } catch (e) {
        if (mounted) CustomToast.show(context, "Error joining: $e", isError: true);
     } finally {
        if (mounted) setState(() => _isCreating = false);
     }
  }

  void _createTournament() async {
    if (_entryFee > 0) {
      int balance = ProgressionService().getCoins();
      if (balance < _entryFee) {
        CustomToast.show(context, "Not enough coins! Need $_entryFee.", isError: true);
        return;
      }
    }

    setState(() => _isCreating = true);
    try {
      if (_entryFee > 0) {
        await ProgressionService().spendCoins(_entryFee);
      }

      final tData = await VPSGameService().createTournament(
        _nameController.text, 
        _gameType, 
        _maxPlayers, 
        _entryFee
      );
      
      if (!mounted) {
        // If unmounted, we can't navigate, but coin is spent. 
        // In a real app we might want more robust atomicity.
        return;
      }
      Tournament tournament = Tournament.fromJson(tData);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (c) => TournamentScreen(
            tournamentId: tournament.id, 
            isHost: true,
            initialTournament: tournament,
        ))
      );
    } catch (e) {
      if (!mounted) return;
      // If error, refund the coins if we spent them
      if (_entryFee > 0) {
        await ProgressionService().addCoins(_entryFee);
      }
      CustomToast.show(context, "Error creating tournament: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _joinTournament() async {
    String code = _joinCodeController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    
    setState(() => _isCreating = true); // Reuse loading state for join
    
    try {
       // We need to know the fee before joining to check balance.
       // However, joinTournament usually does both. 
       // For now, let's assume we fetch tournament info first if we wanted to be precise, 
       // but here we just try to join and assume the server tells us if we fail.
       // Actually, the current flow joins first then returns data.
       
       final tData = await VPSGameService().joinTournament(code);
       if (!mounted) return;
       Tournament tournament = Tournament.fromJson(tData);
       
       // Now check if there was a fee and deduct it
       if (tournament.entryFee > 0) {
          int balance = ProgressionService().getCoins();
          if (balance < tournament.entryFee) {
             // If they joined but can't pay, they should leave.
             // But for now let's just deduct what we can or show error.
             // Better: deduct after successful join if it's an online tournament.
             CustomToast.show(context, "Joined! Entry fee: ${tournament.entryFee} coins.", isError: false);
             bool success = await ProgressionService().spendCoins(tournament.entryFee);
             if (!success) {
                // Should technically leave tournament here
                CustomToast.show(context, "Warning: Insufficient coins for entry fee.", isError: true);
             }
          } else {
             await ProgressionService().spendCoins(tournament.entryFee);
             CustomToast.show(context, "Entry fee of ${tournament.entryFee} coins paid.");
          }
       }

       Navigator.push(
         context,
         MaterialPageRoute(builder: (c) => TournamentScreen(
             tournamentId: code, 
             isHost: false,
             initialTournament: tournament,
         ))
       );
    } catch (e) {
       if (mounted) {
         CustomToast.show(context, "Error joining: $e", isError: true);
       }
    } finally {
       if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("TOURNAMENTS", style: TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- PUBLIC TOURNAMENTS SECTION ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("PUBLIC TOURNAMENTS", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.blueAccent),
                  onPressed: _fetchPublicTournaments,
                )
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10)
              ),
              child: _isLoadingPublic 
                ? const Center(child: CircularProgressIndicator())
                : _publicTournaments.isEmpty
                  ? const Center(child: Text("No public tournaments found", style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _publicTournaments.length,
                      itemBuilder: (context, index) {
                        final t = _publicTournaments[index];
                        return _buildTournamentCard(t);
                      },
                    ),
            ),
            const SizedBox(height: 32),
            const Row(
              children: [
                Expanded(child: Divider(color: Colors.white24)),
                Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("OR JOIN BY CODE", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 10))),
                Expanded(child: Divider(color: Colors.white24)),
              ],
            ),
            const SizedBox(height: 32),
            // --- JOIN SECTION ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withOpacity(0.3))
              ),
              child: Column(
                children: [
                   const Text("JOIN TOURNAMENT", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
                   const SizedBox(height: 16),
                   TextField(
                     controller: _joinCodeController,
                     style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 4),
                     textAlign: TextAlign.center,
                     textCapitalization: TextCapitalization.characters,
                     decoration: InputDecoration(
                        hintText: "ENTER CODE",
                        hintStyle: TextStyle(color: Colors.white38, letterSpacing: 2),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                     ),
                   ),
                   const SizedBox(height: 16),
                   ElevatedButton(
                     onPressed: _joinTournament,
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.blue,
                       minimumSize: const Size(double.infinity, 50),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                     ),
                     child: const Text("JOIN NOW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                   )
                ],
              )
            ),
            
            const SizedBox(height: 40),
            const Row(
              children: [
                Expanded(child: Divider(color: Colors.white24)),
                Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("OR", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))),
                Expanded(child: Divider(color: Colors.white24)),
              ],
            ),
            const SizedBox(height: 40),

            // --- CREATE SECTION ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withOpacity(0.3))
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Center(child: Text("CREATE TOURNAMENT", style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Orbitron'))),
                   const SizedBox(height: 24),
                   
                   const Text("Tournament Name", style: TextStyle(color: Colors.white70)),
                   const SizedBox(height: 8),
                   TextField(
                     controller: _nameController,
                     style: const TextStyle(color: Colors.white),
                     decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                     ),
                   ),
                   const SizedBox(height: 20),

                   const Text("Game Mode", style: TextStyle(color: Colors.white70)),
                   const SizedBox(height: 8),
                   Row(
                     children: [
                       Expanded(
                         child: RadioListTile<String>(
                           title: const Text('Kadi', style: TextStyle(color: Colors.white)),
                           value: 'kadi',
                           groupValue: _gameType,
                           activeColor: Colors.amber,
                           contentPadding: EdgeInsets.zero,
                           onChanged: (val) => setState(() => _gameType = val!),
                         ),
                       ),
                       Expanded(
                         child: RadioListTile<String>(
                           title: const Text('Go Fish', style: TextStyle(color: Colors.white)),
                           value: 'gofish',
                           groupValue: _gameType,
                           activeColor: Colors.amber,
                           contentPadding: EdgeInsets.zero,
                           onChanged: (val) => setState(() => _gameType = val!),
                         ),
                       ),
                     ],
                   ),
                   const SizedBox(height: 10),

                   const Text("Max Players", style: TextStyle(color: Colors.white70)),
                   Slider(
                     value: _maxPlayers.toDouble(),
                     min: 4,
                     max: 16,
                     divisions: 3,
                     activeColor: Colors.amber,
                     label: _maxPlayers.toString(),
                     onChanged: (val) => setState(() => _maxPlayers = val.toInt()),
                   ),
                   
                   const SizedBox(height: 10),

                   const Text("Entry Fee (Coins)", style: TextStyle(color: Colors.white70)),
                   Slider(
                     value: _entryFee.toDouble(),
                     min: 0,
                     max: 1000,
                     divisions: 10,
                     activeColor: Colors.amber,
                     label: _entryFee.toString(),
                     onChanged: (val) => setState(() => _entryFee = val.toInt()),
                   ),
                   Center(child: Text("Total Prize Pool: 🪙 ${_entryFee * _maxPlayers}", style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold))),
                   
                   const SizedBox(height: 24),
                   ElevatedButton(
                     onPressed: _isCreating ? null : _createTournament,
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.amber,
                       minimumSize: const Size(double.infinity, 50),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                     ),
                     child: _isCreating 
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text("CREATE & HOST", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                   )
                ],
              )
            ),
          ],
        ),
      )
    );
  }

  Widget _buildTournamentCard(Map<String, dynamic> t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12)
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: t['gameMode'] == 'kadi' ? Colors.redAccent.withOpacity(0.2) : Colors.blueAccent.withOpacity(0.2),
          child: Text(t['gameMode'][0].toUpperCase(), style: TextStyle(color: t['gameMode'] == 'kadi' ? Colors.redAccent : Colors.blueAccent, fontWeight: FontWeight.bold)),
        ),
        title: Text(t['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text("${t['playerCount'] ?? 0}/${t['maxPlayers']} Players • Fee: 🪙 ${t['entryFee']}", 
          style: const TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: ElevatedButton(
          onPressed: () => _joinTournamentByData(t),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: StadiumBorder()
          ),
          child: const Text("JOIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }
}
