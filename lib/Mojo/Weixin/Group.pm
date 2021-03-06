package Mojo::Weixin::Group;
use Mojo::Weixin::Base 'Mojo::Weixin::Model::Base';
use Mojo::Weixin::Group::Member;
use Mojo::Weixin::Const qw(%FACE_MAP_QQ %FACE_MAP_EMOJI);

has 'id';
has name => '';
has member => sub{[]};

sub displayname { 
    my $self = shift;
    return $self->name if $self->name;
    my $default_name = join "、", map { $_->displayname } grep {defined $_} (grep {$_->id ne $self->client->user->id} @{$self->member})[0..2];
    return $default_name?$default_name:"群名未知";
}
sub new {
    my $class = shift;
    my $self;
    bless $self=@_ ? @_ > 1 ? {@_} : {%{$_[0]}} : {}, ref $class || $class;
    if(exists $self->{member} and ref $self->{member} eq "ARRAY"){
        for( @{ $self->{member} } ){
            $_ = Mojo::Weixin::Group::Member->new($_) if ref $_ ne "Mojo::Weixin::Group::Member";
            $_->_group_id($self->id);
        }
    }
    if( my @code = $self->name=~/<span class="emoji emoji([a-zA-Z0-9]+)"><\/span>/g){
        my %map = reverse %FACE_MAP_EMOJI;
        for(@code){
            my $name = $self->name;
            $name=~s/<span class="emoji emoji$_"><\/span>/exists $map{$_}?"[$map{$_}]":"[未知表情]"/eg;
            $self->name($name);
        }
    }

    $self;
}
sub is_empty{
    my $self = shift;
    return !(ref($self->member) eq "ARRAY"?0+@{$self->member}:0);
}
sub update {
    my $self = shift;
    my $hash = shift;
    for(grep {substr($_,0,1) ne "_"} keys %$hash){
        if($_ eq "member" and ref $hash->{member} eq "ARRAY"){
            next if not @{$hash->{member}};
            my @member = 
            map {$_->_group_id($self->id);$_} 
            map {ref $_ eq "Mojo::Weixin::Group::Member"?$_:Mojo::Weixin::Group::Member->new($_)} 
            @{$hash->{member}};

            if( $self->is_empty() ){
                $self->member(\@member);
            }
            else{
                my($new_members,$lost_members,$sames)=$self->client->array_diff($self->member, \@member,sub{$_[0]->id});
                for(@{$new_members}){
                    $self->add_group_member($_);
                }
                for(@{$lost_members}){
                    $self->remove_group_member($_);
                }
                for(@{$sames}){
                    my($old_member,$new_member) = ($_->[0],$_->[1]);
                    $old_member->update($new_member);
                }
            }
        }
        else{
            if(exists $hash->{$_}){
                if(defined $hash->{$_} and defined $self->{$_}){
                    if($hash->{$_} ne $self->{$_}){
                        my $old_property = $self->{$_};
                        my $new_property = $hash->{$_};
                        $self->{$_} = $hash->{$_};
                        $self->client->emit("group_property_change"=>$self,$_,$old_property,$new_property) if defined $self->client;
                    }
                }
                elsif( ! (!defined $hash->{$_} and !defined $self->{$_}) ){
                    my $old_property = $self->{$_};
                    my $new_property = $hash->{$_};
                    $self->{$_} = $hash->{$_};
                    $self->client->emit("group_property_change"=>$self,$_,$old_property,$new_property) if defined $self->client;
                }
            }
        }
    }
    $self;
}

sub search_group_member{
   my $self = shift;
    my %p = @_;
    if($p{_check_remote}){
        if(wantarray){
            my @g = $self->_search($self->member,@_);
            if(@g){return @g}
            else{
                $self->client->update_group($self);
                return $self->_search($self->member,@_);
            }
        }
        else{
            my $g = $self->_search($self->member,@_);
            if(defined $g){return $g }
            else{
                $self->client->update_group($self);
                return $self->_search($self->member,@_);
            }
        }
    }
    return $self->_search($self->member,@_);
}
sub add_group_member{
    my $self = shift;
    my $member = shift;
    $self->client->die("不支持的数据类型\n") if ref $member ne "Mojo::Weixin::Group::Member";
    $self->client->emit(new_group_member=>$member,$self) if $self->_add($self->member,$member) == 1;
}
sub remove_group_member{
    my $self = shift;
    my $member = shift;
    $self->client->die("不支持的数据类型\n") if ref $member ne "Mojo::Weixin::Group::Member";
    $self->client->emit(lose_group_member=>$member,$self) if $self->_remove($self->member,$member) == 1;
}

sub me {
    my $self = shift;
    return $self->search_group_member(id=>$self->client->user->id);
}
sub members {
    my $self = shift;
    return @{$self->member};
}
sub send{
    my $self = shift;
    $self->client->send_message($self,@_);
}
sub send_media {
    my $self = shift;
    $self->client->send_media($self,@_);
}
sub set_displayname{
    my $self = shift;
    my $displayname = shift;
    $self->client->set_group_displayname($self,$displayname);
}
sub invite_friend{
    my $self = shift;
    $self->client->invite_friend($self,@_)
}
sub kick_group_member{
    my $self = shift;
    $self->client->kick_group_member($self,@_);
}

1;
