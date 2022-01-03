use [HoloJP Karaoke]

--Create tables--
DROP TABLE IF EXISTS Karaoke,Name,Song

Create table Name (
StreamerID int not null PRIMARY KEY,
Name nvarchar(99) not null,
Generation nvarchar(99) not null
)

go

Create table Song (
songID int not null PRIMARY KEY,
Title nvarchar(99) not null ,
Artist nvarchar(99) not null,
Genre nvarchar(99) not null)

go

Create table Karaoke(
KaraokeID int not null PRIMARY KEY,
StreamerID int not null, 
	CONSTRAINT Karaoke_name_FK 
		FOREIGN KEY (StreamerID)
		references Name(StreamerID),
songID int not null ,
	CONSTRAINT Karaoke_song_FK 
		FOREIGN KEY (songID)
		references Song(songID)
)

go

--Add data--
insert into Name values
(1, 'Ookami Mio', 'GAMERS'),
(2, 'Tokoyami Towa', '4'),
(3, 'Shirogane Noel', '3'),
(4, 'Shirakami Fubuki', '1'),
(5, 'Aki Rosenthal', '1'),
(6, 'Roboco', '0'),
(7, 'Oozora Subaru', '2'),
(8, 'Uruha Rushia', '3'),
(9, 'Takane Lui', '6'),
(10, 'Yozora Mel', '1'),
(11, 'Nakiri Ayame', '2'),
(12, 'Amane Kanata', '4'),
(13, 'Sakamata Chloe', '6'),
(14, 'Natsuiro Matsuri', '1'),
(15, 'Usada Pekora', '3'),
(16, 'Hakui Koyori', '6'),
(17, 'Shishiro Botan', '5'),
(18, 'Murasaki Shion', '2'),
(19, 'Omaru Polka', '5'),
(20, 'Tsunomaki Watame', '4'),
(21, 'Akai Haato/Haachama', '1'),
(22, 'Momosuzu Nene', '5'),
(23, 'Minato Aqua', '2'),
(24, 'Hoshimachi Suisei', '0'),
(25, 'Shiranui Flare', '3'),
(26, 'Sakura Miko', '0')

go
--Fill up Song table--
drop table if exists #complete_songlist

go
with songlist(song,artist,genre)
as
(
select distinct song,
				artist,
				genre
from dbo.rawdata
)
select ROW_NUMBER() over (order by song) as songID,
		song,
		artist,
		genre
into #complete_songlist
from songlist

go

insert into Song 
select *
from #complete_songlist


-- Fill up Karaoke table --

insert into Karaoke
select ROW_NUMBER() over (order by sequence) as KaraokeID,
		StreamerID,
		SongID
from dbo.Rawdata a
left join dbo.Name b
on a.Name = b.Name
left join dbo.Song c
on a.Song = c.Title
order by KaraokeID

--Actual Analysis--
--Q1: What is the distribution of streamers and their generations?

select generation,
		count(distinct Name) as No_of_members
from dbo.Karaoke a
inner join dbo.Name b
on a.StreamerID = b.StreamerID
group by Generation

--Q2a: What is the top 3 most popular song?
select top 3 Title,
			count(a.songID) as no_of_times_sang
from Karaoke a
inner join Song b
on a.songID = b.songID
group by Title
order by COUNT(a.songID) desc

--Q2b: Which streamer sang those songs?
select title,
		Name
from Karaoke a
join Name b
on a.StreamerID = b.StreamerID
join Song c
on c.songID = a.songID
where a.songID in
(
		select top 3 a.songID
from Karaoke a
inner join Song b
on a.songID = b.songID
group by a.songID
order by COUNT(a.songID) desc)
order by Title

--Q3a: Who is the top 3 most popular song artist in this karaoke?
select top 3 artist,
			COUNT(artist) as no_of_songs_featured
from Karaoke a
join Song b
on a.songID = b.songID
group by Artist
order by COUNT(artist) desc

--Excluding Hololive--
select top 3 artist,
			COUNT(artist) as no_of_songs_featured
from Karaoke a
join Song b
on a.songID = b.songID
where Artist not like '%Hololive%'
group by Artist
order by COUNT(artist) desc

--3b:Excluding hololive, what songs by top artists were played?
select artist,
		title,
		count(karaoke.songid) as no_of_times_sang
from Song 
join Karaoke
on Song.songID = Karaoke.songID
where Artist in (
select top 3 artist
from Karaoke a
join Song b
on a.songID = b.songID
where Artist not like '%Hololive%'
group by Artist
order by COUNT(artist) desc
)
group by Artist,Title
order by Artist

--Q4: Which song genre is the most popular?
select top 3 genre,
				count(a.songid) as no_of_times_sang
from Karaoke a
inner join Song b
on a.songID = b.songID
group by Genre
order by count(a.songid) desc

--Excluding hololive
select top 3 genre,
				count(a.songid) as no_of_times_sang
from Karaoke a
inner join Song b
on a.songID = b.songID
where Artist not like '%hololive%'
group by Genre
order by count(a.songid) desc

--Q5:Which top 3 streamer sang the most?
select top 3 Name,
		COUNT(a.streamerid) as no_of_songs_sang
from Karaoke a
join Name b
on a.StreamerID = b.StreamerID
group by name
order by COUNT(a.streamerid) desc

--Q6:What is the average number of songs sang per stream?
select round((select count(song)
		from Rawdata)/
		(select count(distinct sequence)
		from Rawdata),2) as average_no_of_songs

--Q7:Are there any songs sang in multiple streams in succession?
go
drop table if exists #karaoke_stream

select karaokeid,
		streamid,
		streamerid,
		songid
into #Karaoke_stream
from 
(select *,
		ROW_NUMBER() over (order by karaokeid) as row_num
from Karaoke) a
join
(select row_number() over (order by sequence) as row_num,
		sequence as streamid
from Rawdata) b
on a.row_num = b.row_num

go

drop table if exists #succession_check

go
with succession(streamerid, streamid,songid,subsequent_songid)
as
(select a.StreamerID,
		a.streamid,
		a.songid,
		b.songid
from #Karaoke_stream a
left join #karaoke_stream b
on a.streamid+1 = b.streamid
)
select *,
		IIF(songid = subsequent_songid, 'TRUE', 'FALSE') as succession_check
into #succession_check
from succession

select title,
		c.Name as first_streamer,
		d.Name as second_streamer
from #succession_check a
inner join Song b
on a.songid = b.songID
inner join name c
on a.streamerid = c.StreamerID
inner join name d
on a.streamerid+1 = d.StreamerID 
where succession_check = 'TRUE'