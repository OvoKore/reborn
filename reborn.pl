#    M              OOOOOOOO
#    A            OO--------OO
#    D          OO--------VVVVOO
#    E        OOVVVV------VVVVVVOO
#             OOVVVV------VVVVVVOO
#    B      OOVVVVVV--------VVVV--OO
#    Y      OOVVVVVV--------------OO
#         OO----------VVVVVV--------OO
#    O    OO--------VVVVVVVVVV------OO
#    V    OOVVVV----VVVVVVVVVV------OO
#    O    OOVVVVVV--VVVVVVVVVV--VV--OO
#    K      OOVVVV----VVVVVV--VVVVOO
#    O      OOVVVV------------VVVVOO
#    R        OOOO--------------OO
#    E            OO--------OOOO
#    !              OOOOOOOO

package autoCollect;

use strict;
use Plugins;
use Globals;
use Misc;
use AI;
use utf8;
use Log qw(error);

Plugins::register("reborn", "reborn now!", \&unload);

my $hooks = Plugins::addHooks(
	['packet/quest_all_mission',	\&check, undef],
	['base_level_changed',		\&levelUp, undef],
	['job_level_changed',		\&jobUp, undef],
	['packet_storage_close',	\&storageClose, undef],
	['packet/actor_info',		\&core_actorInfo, undef],
	['engaged_deal',		\&trade_start, undef],
	['finalized_deal',		\&trade_finalize, undef],
	['complete_deal',		\&trade_complete, undef],
	['npc_exist',			\&npc_found, undef],
	['zeny_change',			\&zeny_changed, undef],
	['packet/map_change', 		\&maze, undef],
	['packet/map_loaded', 		\&valk, undef]
	
);

my $comand = Commands::register(
	['reborn','check reborn',\&cmdCheck]
);

sub unload {
	Plugins::delHooks($hooks);	
}

my $active = 1;
my $check = 1;
my @jobs = [17];
my @player_trade = [""];
my $paidRate = 0;
my $readedBook = 0;

sub cmdCheck {
	$check = 1;
	check();
}

sub check {
	return if (!(checkBasic()));
	if ($check) {
		$check = 0;
		if ($char->{weight} != 0) {
			start();
		}
		else {
			foreach my $questID (keys %{$questList}) {
				if ($questID == 1000) {
					$paidRate = 1;
					last;
				}
			}
			if (!$paidRate && $char->{zeny} != 1285000 && $char->{zeny} != 0 && $char->{weight} == 0) {
				#trade
				manual();
				Commands::run("move yuno_in02 168 61");
			}
			elsif ($char->{zeny} == 1285000 && $char->{weight} == 0) {
				#pay rate
				manual();
				Commands::run("move yuno_in02 90 166");
			}
			elsif ($paidRate && $char->{zeny} == 0 && $char->{weight} == 0 && !$readedBook) {
				#read book
				manual();
				Commands::run("move yuno_in02 93 194");
			}
			elsif ($readedBook) {
				#maze
				manual();
				Commands::run("move yuno_in05 152 142");
			}
		}
	}
}

sub levelUp {
	my ($self, $args) = @_;
	return if (!(checkBasic()));
	start();
}

sub jobUp {
	my ($self, $args) = @_;
	return if (!(checkBasic()));
	start();
}

sub start {
	Commands::run("iconf " . '502' . " 0 1 0");
	Commands::run("iconf " . '656'. " 0 1 0");
	if ($field->name eq $config{lockMap}) {
		main::useTeleport(2);
	}
	AI::clear();
	Commands::run("autosell");
}

sub storageClose {
	return if (!(checkBasic()));
	return if ($char->{weight} != 0);
	manual();
	Commands::run("move yuno_in02 168 61");
}

sub core_actorInfo {
	my ($caller, $args) = @_;
	return if (!(checkBasic()));
	return if ($char->{zeny} == 1285000);
	return if ($char->{zeny} == 0);
	my $name = get_player_name($args->{ID});
	if ($name ~~ @player_trade) {
		#TODO aproximar do char para dar trade (mas no caso, o char sempre vai estar ao lado)
		manual();
		$messageSender->sendDeal($args->{ID});
	}
}

sub trade_start {
	my ($self, $args) = @_;
	return if (!(checkBasic()));
	$messageSender->sendDealAddItem(pack('v', 0), $char->{'zeny'});
	sleep(0.5);
	$messageSender->sendToServer($messageSender->reconstruct({switch => 'deal_finalize'}));
}

sub trade_finalize {
	my ($self, $args) = @_;
	return if (!(checkBasic()));
	$messageSender->sendToServer($messageSender->reconstruct({switch => 'deal_trade'}));
}

sub trade_complete {
	return if (!(checkBasic()));
	if ($char->{'zeny'} = 1285000) {
		Commands::run('move yuno_in02 90 166');
	}
}

sub npc_found {
	my ($self, $args) = @_;
	return if (!(checkBasic()));
	my $npc = $args->{npc};
	if (!$paidRate && $npc->{nameID} == 56970) { #Metheus Sylphe#Libray
		AI::clear();
		Commands::run("talknpc 88 164 r0");
		$paidRate = 1;
	}
	elsif ($paidRate && $npc->{nameID} == 56971) { #Livro de Ymir
		AI::clear();
		Commands::run("move yuno_in05 152 142");
		Commands::run("talknpc 93 207");
		$readedBook = 1;
	}
	elsif ($paidRate && $npc->{nameID} == 56972) { #Coração de Ymir
		AI::clear();
		Commands::run("talknpc 49 43");
	}
	elsif ($paidRate && $npc->{nameID} == 60114) { #valkyrie
		AI::clear();
		Commands::run("talknpc 48 86");
	}
}

sub zeny_changed {
	my ($self, $args) = @_;
	return if (!(checkBasic()));
	if ($args->{zeny} == 0 && $args->{change} == -1285000) {
		$paidRate = 1;
		AI::clear();
		Commands::run("move yuno_in02 93 194");
	}
}

sub maze {
	return if (!(checkBasic()));
	if ($field->name eq "yuno_in05") {
		my $x = $char->position()->{x};
		my $y = $char->position()->{y};
		if ($x == 145 && $y == 83) {
			Commands::run("move yuno_in05 136 71");
		}
		elsif ($x == 177 && $y == 49) {
			Commands::run("move yuno_in05 177 146");
		}
		elsif ($x == 177 && $y == 12) {
			Commands::run("move yuno_in05 177 8");
		}
		elsif (($x == 192 && $y == 103) ||
			   ($x == 181 && $y == 94) ||
			   ($x == 181 && $y == 113)) {
			Commands::run("move yuno_in05 164 102");
		}
		elsif ($x == 15 && $y == 185) {
			Commands::run("move yuno_in05 31 167");
		}
		elsif ($x == 50 && $y == 85) {
			Commands::run("move yuno_in05 38 42");
		}
	}
}

sub valk {
	return if (!(checkBasic()));
	if ($field->name eq "valkyrie") {
		AI::clear();
		Commands::run("move valkyrie 43 86");
	}
}

sub get_player_name {
	my ($ID) = @_;
	my $player = Actor::get($ID);
	my $name = $player->name;
	return $name;
}

sub manual {
	AI::state(AI::MANUAL);
	AI::clear();
}

sub checkBasic {
	return ($char->{lv} == 99 && $char->{lv_job} == 50 && $char->{jobID} ~~ @jobs && $active);
}

1;
#Nossa natureza é o caos.
