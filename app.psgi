#!/usr/bin/env perl
use strict;
use warnings;

use Plack::Request;
use LINE::Bot::API;
use LINE::Bot::API::Builder::SendMessage;
use LINE::Bot::API::Builder::TemplateMessage;
use WebService::YDMM;
use List::Util qw/shuffle/;
use utf8;
use Encode;
use DDP { deparse => 1 };

my $bot = LINE::Bot::API->new(
    channel_secret => $ENV{LINE_SECRET},
    channel_access_token => $ENV{LINE_TOKEN},
);

my $dmm = WebService::YDMM->new(
    affiliate_id => $ENV{DMM_AFFI},
    api_id      =>  $ENV{DMM_API},
);

sub {
    my $req = Plack::Request->new(shift);

    unless ($bot->validate_signature($req->content,$req->header('X-Line-Signature'))) {
        return [200, [], ['bad request']];
    }

    my $events = $bot->parse_events_from_json($req->content);

    for my $event (@{ $events }) {
        if ($event->is_user_event && $event->is_message_event && $event->is_text_message) {

            if ($event->text eq "使い方" ){
                my $info = "[教えて] もしくは [2ページ] というと教えてくれます";
                my $messages = LINE::Bot::API::Builder::SendMessage->new()->add_text( text => $info);
                my $res = $bot->reply_message($event->reply_token,$messages->build);
                p $res;
                ... unless $res->is_success; # error handling
                next;
            }


            if ($event->text !~ /教えて|[0-9]ページ/){
                my @message = (qw/
                                    芸術家といふのは自然の変種です。
                                    人間、正道を歩むのは却つて不安なものだ。
                                    男といふものは、もし相手の女が、彼の肉体だけを求めてゐたのだとわかると、一等自尊心を鼓舞されて、大得意になるといふ妙なケダモノであります
                                    「強み」とは何か。知恵に流されぬことである。分別に溺れないことである
                                    この世に一つ幸福があれば必ずそれに対応する不幸が一つある筈だ
                                    /);

                my $rand_m = ((shuffle(@message))[0]);

                my $messages = LINE::Bot::API::Builder::SendMessage->new()->add_text( text => $rand_m);
                my $res = $bot->reply_message($event->reply_token,$messages->build);
                p $res;
                ... unless $res->is_success; # error handling
                next;
            }
    
            my $offset = 1;

            if ($event->text =~ /([0-9]+)ページ/){
                $offset = ($1-1) * 10;
                $offset = 1 if $offset == 0;
            }

            my $sell_id = 6565;

            my $items = $dmm->item("DMM.R18", +{ sort => "ranking", service => "digital", floor => "videoa", article => "keyword" , hits => 10, article_id => $sell_id ,offset => $offset})->{items};

            if ( @{$items} == 0){
                my $messages = LINE::Bot::API::Builder::SendMessage->new()->add_text( text => "なんか見つかんなかった…");
                my $res = $bot->reply_message($event->reply_token,$messages->build);
                ... unless $res->is_success; # error handling
                next;
            }

            my $carousel = LINE::Bot::API::Builder::TemplateMessage->new_carousel(
                alt_text => 'this is a dmm videos',
            );

            for my $item (@{$items}) {

                my $image_url = $item->{imageURL}->{large};
                my $item_uri  = $item->{affiliateURLsp};
                my $title = $item->{title};


                if ($image_url =~ /http:/){
                    $image_url =~ s/http:/https:/;
                }


                if ($item_uri =~ /http:/){
                    $item_uri =~ s/http:/https:/;
                }


                if ( length $title >= 40 ){
                    $title = substr($title,0,39);
                }

                my $col = LINE::Bot::API::Builder::TemplateMessage::Column->new(
                    image_url => $image_url,
                    title     => $title,
                    text      => "Please Selecet",
                )->add_uri_action(
                    label   => 'DMMで見る',
                    uri     => $item_uri,
                );
                $carousel->add_column($col->build);
            }


            my $messages = LINE::Bot::API::Builder::SendMessage->new()->add_template($carousel->build);
            my $res = $bot->reply_message($event->reply_token,$messages->build);
            p $res;
            ... unless $res->is_success; # error handling
        }
    }
    return [200, [], ["OK"]];
};
