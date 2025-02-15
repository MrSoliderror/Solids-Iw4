#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\gametypes\_hud_util;

CONST_MAP_VOTE_SIZE = 6;

init()
{
    level.is_voting             = false;
    level.votemaps              = [];

    if ( !fileExists( "map_voting.cfg" ) )
    {
        iPrintLn( "map_voting.cfg not found, aborting vote..." );
        return;
    }

    if ( !fileExists( "map_data.csv" ) )
    {
        iPrintLn( "map_data.csv not found, aborting vote..." );
        return;
    }
    
    config = strTok( fileRead( "map_voting.cfg" ), "\r\n" );
    config = array_remove( config, getDvar( "mapname" ) );

    if ( config.size < CONST_MAP_VOTE_SIZE )
    {
        iPrintLn( "Not enough maps specified in map_voting.cfg, aborting vote..." );
        gameFlagSet( "disable_map_voting" );
        return;
    }

    gameFlagSet( "map_voting_active" );

    for ( i = 0; i < CONST_MAP_VOTE_SIZE; i++ )
    {
        potential_map           = config[ randomInt( config.size ) ];
        level.votemaps[i]       = spawnStruct();
        level.votemaps[i].ID    = potential_map;
        level.votemaps[i].votes = 0;
        config = array_remove( config, potential_map );
        makeDvarServerInfo( "map_vote_id_" + i, level.votemaps[i].ID );
        makeDvarServerInfo( "map_vote_count_" + i, 0 );
    }
}

start_map_vote()
{
    level.is_voting = true;

    foreach ( player in level.players )
    {
        if ( player isTestClient() )
            kick( player getEntityNumber() );

        player.vote_id      = undefined;
        player.sessionstate = "spectator";
        player thread monitor_disconnect();

        waitframe();

        player openPopupMenu( "map_voting" );
    }

    wait 10;
    map( get_winning_map() );
}

get_winning_map()
{
    level.is_voting = false;
    winner          = level.votemaps[0];

    for( i = 1; i < CONST_MAP_VOTE_SIZE; i++ )
    {
        if ( isDefined( level.votemaps[i] ) && level.votemaps[i].votes > winner.votes )
            winner = level.votemaps[i];
    }

    setDvar( "sv_mapRotation", "map " + winner.ID );
	setDvar( "sv_mapRotationCurrent", "map " + winner.ID );
    return winner.ID;
}

monitor_disconnect()
{
    self waittill( "disconnect" );

    if ( isDefined( self.vote_id ) )
    {
        level.votemaps[self.vote_id].votes--;
        makeDvarServerInfo( "map_vote_count_" + self.vote_id, level.votemaps[self.vote_id].votes );
    }
}

cast_map_vote( idx )
{
    if ( !level.is_voting )
        return;

    if ( isDefined( self.vote_id ) && idx == self.vote_id )
        return;

    if ( idx > CONST_MAP_VOTE_SIZE || idx < 0 )
        return;

    level.votemaps[self.vote_id].votes--;
    level.votemaps[idx].votes++;

    makeDvarServerInfo( "map_vote_count_" + self.vote_id, level.votemaps[self.vote_id].votes );
    makeDvarServerInfo( "map_vote_count_" + idx, level.votemaps[idx].votes );

    self.vote_id = idx;
}