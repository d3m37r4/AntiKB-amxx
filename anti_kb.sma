/*
    credits:
        - bugsy for aim detector
*/
#include < amxmodx >
#include < amxmisc >
#include < fakemeta >
#include < fakemeta_util >
#include < hamsandwich >


new const VERSION[] = "1.3.5";

#define DEFAULT_ROUNDS      1
#define DEFAULT_NAME        "Player"

new g_iBotID, g_iBotRounds;
new g_iRoundCounter;
new g_iTmpID;
new g_iBotCreator, g_iTarget;
new HamHook:HamKilled, fwServerFrame;
new bool:g_bInvisible;

#if AMXX_VERSION_NUM < 183
    enum CsTeams
    {
        CS_TEAM_UNASSIGNED = 0,
        CS_TEAM_T          = 1,
        CS_TEAM_CT         = 2,
        CS_TEAM_SPECTATOR  = 3
    };
#endif
public plugin_init(){

    register_plugin( "KB Check", VERSION, "DusT" );

    register_concmd( "amx_kb_check",     "AttachEntity",     ADMIN_LEVEL_A, "< nick | authid | #uid > [rounds]" );
    register_concmd( "amx_kb_remove",    "RemoveBotCheck",   ADMIN_LEVEL_A );
    register_clcmd ( "say /visible",     "ToggleVisible" );
    register_event( "StatusValue", "ShowStatus", "be"   , "2!0"         );
    register_event( "HLTV"       , "RoundStart", "a"    , "1=0", "2=0"  );
    
    register_logevent( "RoundEnd", 2 , "1=Round_End" );
    
    DisableHamForward( HamKilled = RegisterHam( Ham_Killed, "player", "fw_PlayerKilled" ) );

    register_forward( FM_AddToFullPack, "fw_AddToFullPack", 1 );
}

public fw_StartFrame( )
{
    if( g_iBotID ){
        static Float:flFrameTime;
        global_get( glb_frametime, flFrameTime );
        //engfunc( EngFunc_RunPlayerMove, client_index, view angle, forward speed, side speed, up speed, buttons, impulse, duration )
        engfunc( EngFunc_RunPlayerMove, g_iBotID, Float:{ 0.0, 0.0, 0.0 }, 0.0, 0.0, 0.0, 0, 0, floatround( flFrameTime * 1000.0 ) );
    }
    return FMRES_IGNORED;
}

public ToggleVisible( id )
{
    if( id == g_iBotCreator )
    {
        g_bInvisible = !g_bInvisible;
        client_print( id, print_chat, "** Bot is %svisible.", g_bInvisible? "not ":"" );
    }
        
    return PLUGIN_HANDLED;
}
public fw_AddToFullPack( es_handle, e, iEnt, iHost, iHostflags, bPlayer, pSet )
{
    if( iEnt == g_iBotID )
    {
        if( bPlayer && g_iBotCreator && g_iBotCreator == iHost && !g_bInvisible )
        {
            set_es( es_handle, ES_RenderAmt, 255 );
            //client_print( iHost, print_chat, "11111");
        } 
        else
        {
            set_es( es_handle, ES_RenderAmt, 0 );
            //client_print( iHost, print_chat, "2222");
        }

        if( iHost == g_iTarget && is_user_alive( g_iBotID ) && is_user_alive( g_iTarget ) )
        {
            static Float:fOrigin[ 3 ];
            pev( g_iTarget, pev_origin, fOrigin );
            engfunc( EngFunc_SetOrigin, g_iBotID, fOrigin );
        }            
    }
}
public RoundStart( )
{
    if( g_iBotID && g_iTmpID && is_user_connected( g_iTmpID ) )
    {
        set_task( 2.0, "SetCreateBot" );
    }
        
}
public SetCreateBot( )
{
    if( g_iBotID && g_iTmpID && is_user_connected( g_iTmpID ) )
    {
        g_iBotID = 0;
        CreateBot( g_iTmpID, g_iBotRounds );
    }
}
public RoundEnd()
{
    if( g_iBotID )
    {
        g_iRoundCounter++; 
        if( g_iRoundCounter >= g_iBotRounds )
        {
            RemoveBot( );
        }
            
    }
}
public RemoveBotCheck( id, iLevel, iCid )
{
    if( cmd_access(id, iLevel, iCid, 0 ) )
    {
        RemoveBot();
    }
    return PLUGIN_HANDLED;
}
//block name from being visible to other players.
public ShowStatus( id )
{
    new iTarget;
    static msgStatusText;

    iTarget = read_data( 2 );

    if( iTarget == g_iBotID && ( msgStatusText || ( msgStatusText = get_user_msgid( "StatusText" ) ) ) )
    {
        message_begin( MSG_ONE_UNRELIABLE, msgStatusText, _, id );
        write_byte( 0 );
        write_string( "" );
        message_end( );
    }
}
public AttachEntity( id, iLevel, iCid )
{
    if( !cmd_access( id, iLevel, iCid, 1 ) )
    {
        return PLUGIN_HANDLED; 
    }
        
    if( g_iBotID )
    {
        if( id )
        {
            client_print( id, print_console, "[KB] You can't create a bot right now." );
        }
        return PLUGIN_HANDLED;
    }

    new szName[32], szRounds[3], iPlayer, iRoundNum;
    read_argv( 1, szName,   charsmax( szName  ) );
    read_argv( 2, szRounds,  charsmax( szRounds ) );

    if( !strlen( szRounds ) || ( iRoundNum = str_to_num( szRounds ) ) <= 0 )
    {
        iRoundNum = DEFAULT_ROUNDS;
    }

    iPlayer = cmd_target( id, szName, CMDTARGET_ALLOW_SELF | CMDTARGET_NO_BOTS );

    if( iPlayer && is_user_alive( iPlayer ) )
    {
        g_iBotCreator = id;
        CreateBot( iPlayer, iRoundNum );
    }
    return PLUGIN_HANDLED;
}
//bot creation from bugsy's aim detect plugin
public CreateBot( id, iRounds ){
    if( g_iBotID || !is_user_alive( id ) )
    {
        return PLUGIN_HANDLED;
    }
    new szRejected[ 128 ];

    g_iBotID = engfunc( EngFunc_CreateFakeClient, DEFAULT_NAME );
	
    if ( !g_iBotID )
    {
        return PLUGIN_HANDLED;
    }
		
    engfunc( EngFunc_FreeEntPrivateData, g_iBotID );

    dllfunc( DLLFunc_ClientConnect, g_iBotID , DEFAULT_NAME , "127.0.0.1" , szRejected );
    dllfunc( DLLFunc_ClientPutInServer, g_iBotID );

    set_pev( g_iBotID , pev_flags , pev( g_iBotID , pev_flags ) | FL_FAKECLIENT );

	// enemy team
    engclient_cmd( g_iBotID , "jointeam" , ( get_user_team( id ) == 1 ) ? "2" : "1" );
    engclient_cmd( g_iBotID , "joinclass" , "1" );

    g_iTarget = id;
    g_iBotRounds = iRounds;
    g_iTmpID = 0;

    set_pev( g_iBotID, pev_solid, SOLID_NOT );
	//Spawn bot
    fm_user_spawn( g_iBotID );

    fm_set_user_rendering( g_iBotID, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, 0 );     //Invisible

    //forwards
    EnableHamForward( HamKilled );
    fwServerFrame = register_forward( FM_StartFrame, "fw_StartFrame", 1 );
    if( g_iBotCreator )
    {
        client_print( g_iBotCreator, print_chat, "** Bot is active" );
    }

    
    return PLUGIN_HANDLED;
}

public client_disconnected( id ){
    if( g_iBotID )
    {
        if( !g_iTmpID && id == g_iBotID )
        {
            RemoveBot( false );
        }
        else if( !g_iTmpID && id == g_iTarget )
        {
            RemoveBot( );
        }
    }
}
    //should bot get kicked//if temp == true, bot will respawn next round
RemoveBot( bool:bKick = true, bool:bTemp = false ){
    if( !g_iBotID )
    {
        return PLUGIN_HANDLED;
    }
        
    DisableHamForward( HamKilled );
    unregister_forward( FM_StartFrame, fwServerFrame, 1 );
    fm_set_user_rendering( g_iBotID, kRenderFxNone, 255, 255, 255, kRenderNormal, 255 );
    if( bKick )
    {
        server_cmd( "kick #%d", get_user_userid( g_iBotID ) );
    }
    if( bTemp )
    {
        g_iTmpID = g_iTarget;
    }
    else
    {
        g_iBotID = 0;
        g_iRoundCounter = 0;
        g_iTmpID = 0;
    }

    g_iTarget = 0;

    return PLUGIN_HANDLED;
}


public fw_PlayerKilled( iVictim, iKiller )
{
    new iTargetTeam;
    iTargetTeam = get_user_team( iVictim );

    if( iVictim == g_iTarget )
    {
        RemoveBot( true, true );
        return HAM_IGNORED;
    }
    if( iTargetTeam != get_user_team( g_iBotID ) )
    {
        return HAM_IGNORED;
    }
    new iPlayers[32], iNum, iTeamCount[ CsTeams ];

    // get players with with "e" flag and team doesnt work well on 1.8.2 ( idk about 1.9 )
    get_players( iPlayers, iNum, "ac" );

    for( new i = 0; i < iNum; i++ )
    {
        iTeamCount[ CsTeams:get_user_team( iPlayers[ i ] ) ]++;
    }
    //client_print(0, print_chat, "Alive enemy: %d", teamCount[CsTeams:get_user_team(iVictim)])
    if( !iTeamCount[ CsTeams:get_user_team( iVictim ) ] && g_iBotID )
    {
        RemoveBot( true, true ); 
    }
        
    return HAM_IGNORED;
}

public fm_user_spawn( id ) 
{ 
    static msgTeamInfo;

    set_pev( id , pev_deadflag , DEAD_RESPAWNABLE );

    dllfunc( DLLFunc_Spawn , id );

    set_pev( id, pev_iuser1, 0 );

    if( msgTeamInfo || ( msgTeamInfo = get_user_msgid( "TeamInfo" ) ) )
    {
        message_begin( MSG_ALL , msgTeamInfo , _ , 0 );
        write_byte( g_iBotID );
        write_string( "SPECTATOR" );
        message_end( );
    }

    set_pev( g_iBotID, pev_solid, SOLID_NOT );

}
