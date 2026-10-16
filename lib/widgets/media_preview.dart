import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class MediaPreview extends StatefulWidget {
  const MediaPreview({super.key,required this.url,required this.type, this.height=240});
  final String url; final String type; final double height;
  @override State<MediaPreview> createState()=>_MediaPreviewState();
}
class _MediaPreviewState extends State<MediaPreview>{VideoPlayerController? controller;@override void initState(){super.initState();if(widget.type=='video'){controller=VideoPlayerController.networkUrl(Uri.parse(widget.url))..initialize().then((_){if(mounted)setState((){});});}}@override void dispose(){controller?.dispose();super.dispose();}
@override Widget build(BuildContext context){if(widget.type!='video')return Image.network(widget.url,width:double.infinity,height:widget.height,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox(height:80,child:Center(child:Icon(Icons.broken_image_outlined))));final c=controller;if(c==null||!c.value.isInitialized)return SizedBox(height:widget.height,child:const Center(child:CircularProgressIndicator()));return GestureDetector(onTap:(){setState(()=>c.value.isPlaying?c.pause():c.play());},child:Stack(alignment:Alignment.center,children:[SizedBox(width:double.infinity,height:widget.height,child:VideoPlayer(c)),if(!c.value.isPlaying)const CircleAvatar(radius:28,child:Icon(Icons.play_arrow))]));}}
