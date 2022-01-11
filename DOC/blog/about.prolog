:- module(about, [title/1,
                  admin/1,
                  email/1,
                  domain/1,
                  abstract/1]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Put your blog's information here %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

title('REFUSR Internal Blog').
admin('Olivia Lucca Fraser').
email('lucca.fraser@special-circumstanc.es').
domain('refusr.eschatronics.ca').
timezone(4).
port(8008).
bind(localhost).
abstract('An internal blog for the REFUSR working group.').
repo('https://github.com/REFUSR/REFUSR').

