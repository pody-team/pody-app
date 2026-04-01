import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:pody/episode_companion/models/episode_companion_block.dart';
import 'package:pody/episode_companion/renderer/episode_companion_block_renderer.dart';
import 'package:pody/models/models.dart';

const Color _companionCanvas = Color(0xFFFFFBF6);
const Color _companionSurfaceStrong = Color(0xFFF4E7D2);
const Color _companionPrimary = Color(0xFFBF5700);
const Color _companionNeutral = Color(0xFF3E2723);
const Color _companionMuted = Color(0xFF7E665F);
const Color _companionBorder = Color(0xFFE7D6C3);

class EpisodeCompanionSection extends StatefulWidget {
  const EpisodeCompanionSection({
    super.key,
    required this.show,
    required this.episode,
  });

  final Show show;
  final Episode episode;

  @override
  State<EpisodeCompanionSection> createState() =>
      _EpisodeCompanionSectionState();
}

class _EpisodeCompanionSectionState extends State<EpisodeCompanionSection> {
  @override
  Widget build(BuildContext context) {
    final blocks = _buildBlocksForPodcast();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Text(
            'Khám phá nội dung',
            style: GoogleFonts.newsreader(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _companionNeutral,
            ),
          ),
        ),
        const SizedBox(height: 14),
        ...blocks.map(
          (block) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openBlockSheet(context, block),
              child: EpisodeCompanionBlockRenderer(
                key: ValueKey('${block.type.name}-preview'),
                block: block,
                mode: EpisodeCompanionRendererMode.preview,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openBlockSheet(
    BuildContext context,
    EpisodeCompanionBlock block,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _companionCanvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.88,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _companionMuted.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        _iconForBlock(block.type),
                        color: _companionPrimary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _labelForBlock(block.type),
                        style: GoogleFonts.newsreader(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _companionNeutral,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _companionSurfaceStrong,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _companionBorder),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(14),
                        child: EpisodeCompanionBlockRenderer(
                          block: block,
                          mode: EpisodeCompanionRendererMode.full,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<EpisodeCompanionBlock> _buildBlocksForPodcast() {
    switch (widget.show.category) {
      case 'Điều tra':
        return _storyBlocks();
      case 'Công nghệ':
        return _learningBlocks();
      default:
        return _defaultBlocks();
    }
  }

  List<EpisodeCompanionBlock> _storyBlocks() {
    return [
      EpisodeCompanionBlock(
        type: EpisodeCompanionBlockType.timeline,
        data: const TimelineBlockData(
          title: 'Timeline vu viec',
          subtitle: 'Cac moc dang chu y duoc ghim theo dien bien tap.',
          items: [
            TimelineBlockItemData(
              timeLabel: '03:20',
              title: 'Nan nhan bien mat',
              body: 'Lan cuoi cung xuat hien o bai xe phia sau khu thuong mai.',
            ),
            TimelineBlockItemData(
              timeLabel: '12:40',
              title: 'Manh moi dau tien',
              body: 'Camera mo nhung du de xac nhan chiec sedan mau den.',
            ),
            TimelineBlockItemData(
              timeLabel: '21:15',
              title: 'Nhan chung doi loi khai',
              body: 'Chi tiet nay mo ra nghi van ve moi quan he noi bo.',
            ),
            TimelineBlockItemData(
              timeLabel: '33:05',
              title: 'DNA khop sau 20 nam',
              body: 'Buoc ngoat quyet dinh de dong lai cold case.',
            ),
          ],
        ),
      ),
      EpisodeCompanionBlock(
        type: EpisodeCompanionBlockType.chapterList,
        data: const ChapterListBlockData(
          title: 'Case chapters',
          chapters: [
            ChapterListItemData(
              timeLabel: '00:40',
              title: 'Mo dau ho so',
              detail: 'Tong hop boi canh va nhung chi tiet ban dau cua vu an.',
            ),
            ChapterListItemData(
              timeLabel: '14:10',
              title: 'Doi chieu loi khai',
              detail: 'So sanh loi ke cua 3 nhan chung quan trong.',
            ),
            ChapterListItemData(
              timeLabel: '29:55',
              title: 'DNA va buoc ngoat',
              detail: 'Bang chung moi buoc dau mo khoa toan bo cau chuyen.',
            ),
          ],
        ),
      ),
      EpisodeCompanionBlock(
        type: EpisodeCompanionBlockType.diagramImage,
        data: DiagramImageBlockData(
          title: 'Case board',
          subtitle:
              'Mockup cho block so do dieu tra, co the mo fullscreen sau.',
          imageUrl: widget.episode.images.length > 1
              ? widget.episode.images[1]
              : widget.show.imageUrl,
          chips: const [
            'Nan nhan',
            'DNA',
            'Xe den',
            'Nhan chung',
            'Bang chung',
          ],
        ),
      ),
      EpisodeCompanionBlock(
        type: EpisodeCompanionBlockType.quote,
        data: const QuoteBlockData(
          title: 'Key quote',
          quote: 'The evidence was right there. We just did not see it.',
          attribution: 'Detective Minh',
          footnote: 'Mot cau noi dong vai tro chuyen huong cho toan bo tap.',
        ),
      ),
      EpisodeCompanionBlock(
        type: EpisodeCompanionBlockType.storyCast,
        data: const StoryCastBlockData(
          title: 'Nhan vat chinh',
          cards: [
            InfoCardData(
              title: 'Nan nhan',
              body: 'Mat tich tu 1995, ho so tung bi xep lanh suot 2 thap ky.',
            ),
            InfoCardData(
              title: 'Dieu tra vien',
              body: 'Nguoi phat hien chi tiet lech trong loi khai cu.',
            ),
            InfoCardData(
              title: 'Nhan chung',
              body: 'Loi khai thay doi 3 lan, la chia khoa cua toan bo tap.',
            ),
          ],
        ),
      ),
    ];
  }

  List<EpisodeCompanionBlock> _learningBlocks() {
    return [
      EpisodeCompanionBlock(
        type: EpisodeCompanionBlockType.takeaway,
        data: const TakeawayBlockData(
          title: 'Key takeaways',
          items: [
            'MVC van dung tot neu kiem soat duoc do phong cua controller.',
            'MVVM hop khi UI co state thay doi thuong xuyen.',
            'MVP de test luong hon nhung verbose hon.',
          ],
        ),
      ),
      EpisodeCompanionBlock(
        type: EpisodeCompanionBlockType.chapterList,
        data: const ChapterListBlockData(
          title: 'Lesson roadmap',
          chapters: [
            ChapterListItemData(
              timeLabel: '02:15',
              title: 'MVC dat van de gi?',
              detail: 'Tai sao controller bi phong to khi du an lon len.',
            ),
            ChapterListItemData(
              timeLabel: '10:40',
              title: 'MVVM vao cuoc',
              detail: 'Cach ViewModel giam tai cho layer giao dien.',
            ),
            ChapterListItemData(
              timeLabel: '22:05',
              title: 'MVP dung luc nao',
              detail: 'Trade-off giua de test va do verbose cua code.',
            ),
          ],
        ),
      ),
      EpisodeCompanionBlock(
        type: EpisodeCompanionBlockType.diagramImage,
        data: DiagramImageBlockData(
          title: 'Architecture map',
          subtitle: 'Mockup cho block so do, hop voi podcast hoc va cong nghe.',
          imageUrl: widget.episode.images.length > 1
              ? widget.episode.images[1]
              : widget.show.imageUrl,
          chips: const [
            'View',
            'Controller',
            'Model',
            'ViewModel',
            'Presenter',
          ],
        ),
      ),
      EpisodeCompanionBlock(
        type: EpisodeCompanionBlockType.quote,
        data: const QuoteBlockData(
          title: 'Memorable quote',
          quote:
              'The problem is not MVC itself. The problem is how much you let the controller absorb.',
          attribution: 'Anh Ba',
          footnote:
              'Dang quote card cho podcast hoc, co the trich ra de share.',
        ),
      ),
      EpisodeCompanionBlock(
        type: EpisodeCompanionBlockType.quiz,
        data: const QuizBlockData(
          title: 'Quick check',
          question: 'Trong tap nay, van de chinh cua MVC duoc nhac den la gi?',
          options: [
            'Khong ho tro mobile',
            'Controller de bi phong to',
            'Kho render animation',
            'Khong dung duoc voi API',
          ],
          correctIndex: 1,
          explanation:
              'Diem ma tap nhan manh la hien tuong "Massive View Controller", khong phai MVC loi thoi.',
        ),
      ),
      EpisodeCompanionBlock(
        type: EpisodeCompanionBlockType.flashcards,
        data: const FlashcardsBlockData(
          title: 'Flashcards',
          cards: [
            FlashcardItemData(
              front: 'MVC',
              back:
                  'Model - View - Controller. Phan tach trach nhiem nhung de gay phong controller.',
            ),
            FlashcardItemData(
              front: 'MVVM',
              back:
                  'Model - View - ViewModel. Hop voi UI co state va binding ro rang.',
            ),
            FlashcardItemData(
              front: 'MVP',
              back:
                  'Model - View - Presenter. Presenter dieu khien View chu dong hon.',
            ),
          ],
        ),
      ),
    ];
  }

  List<EpisodeCompanionBlock> _defaultBlocks() {
    return [
      EpisodeCompanionBlock(
        type: EpisodeCompanionBlockType.takeaway,
        data: TakeawayBlockData(
          title: 'Diem noi bat',
          items: [
            widget.episode.description,
            'Block dang anh, timeline, quiz co the bat tuy tung show.',
          ],
        ),
      ),
      EpisodeCompanionBlock(
        type: EpisodeCompanionBlockType.quote,
        data: const QuoteBlockData(
          title: 'Quote',
          quote:
              'Companion blocks nen duoc chon theo tung loai show, khong nen dung mot bo cho tat ca.',
          attribution: 'Pody Companion',
        ),
      ),
      EpisodeCompanionBlock(
        type: EpisodeCompanionBlockType.diagramImage,
        data: DiagramImageBlockData(
          title: 'Visual note',
          subtitle: 'Block anh mac dinh cho cac podcast chua co pack rieng.',
          imageUrl: widget.episode.images.isNotEmpty
              ? widget.episode.images.first
              : widget.show.imageUrl,
          chips: widget.episode.tags.take(3).toList(),
        ),
      ),
    ];
  }

  String _labelForBlock(EpisodeCompanionBlockType type) {
    switch (type) {
      case EpisodeCompanionBlockType.timeline:
        return 'Timeline';
      case EpisodeCompanionBlockType.diagramImage:
        return 'Visual';
      case EpisodeCompanionBlockType.takeaway:
        return 'Takeaways';
      case EpisodeCompanionBlockType.quiz:
        return 'Quiz';
      case EpisodeCompanionBlockType.storyCast:
        return 'Nhan vat';
      case EpisodeCompanionBlockType.quote:
        return 'Quote';
      case EpisodeCompanionBlockType.chapterList:
        return 'Chapters';
      case EpisodeCompanionBlockType.flashcards:
        return 'Flashcards';
    }
  }

  IconData _iconForBlock(EpisodeCompanionBlockType type) {
    switch (type) {
      case EpisodeCompanionBlockType.timeline:
        return Icons.timeline;
      case EpisodeCompanionBlockType.diagramImage:
        return Icons.image_outlined;
      case EpisodeCompanionBlockType.takeaway:
        return Icons.lightbulb_outline;
      case EpisodeCompanionBlockType.quiz:
        return Icons.quiz_outlined;
      case EpisodeCompanionBlockType.storyCast:
        return Icons.people_outline;
      case EpisodeCompanionBlockType.quote:
        return Icons.format_quote;
      case EpisodeCompanionBlockType.chapterList:
        return Icons.menu_book_outlined;
      case EpisodeCompanionBlockType.flashcards:
        return Icons.style_outlined;
    }
  }
}
