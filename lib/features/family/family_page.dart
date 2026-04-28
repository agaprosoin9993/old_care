import 'package:flutter/material.dart';

import '../../models/contact.dart';
import '../../services/api_client.dart';

class FamilyPage extends StatefulWidget {
  const FamilyPage({
    super.key,
    required this.api,
    required this.isAuthed,
    required this.contacts,
    this.emergencyContactId1,
    this.emergencyContactId2,
    required this.onSetEmergency1,
    required this.onSetEmergency2,
    required this.onContactsChanged,
  });

  final ApiClient api;
  final bool isAuthed;
  final List<Contact> contacts;
  final int? emergencyContactId1;
  final int? emergencyContactId2;
  final ValueChanged<Contact> onSetEmergency1;
  final ValueChanged<Contact> onSetEmergency2;
  final ValueChanged<List<Contact>> onContactsChanged;

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  bool loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.contacts.isEmpty) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!widget.isAuthed) return;
    setState(() => loading = true);
    try {
      final contacts = await widget.api.fetchContacts();
      widget.onContactsChanged(contacts);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败: $e')));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _addOrEdit({Contact? contact}) async {
    final result = await showDialog<Contact>(
      context: context,
      builder: (_) => _ContactDialog(contact: contact),
    );
    if (result == null) return;
    setState(() => loading = true);
    try {
      if (result.id == null) {
        final created = await widget.api.createContact(result);
        if (created != null) {
          final newList = [...widget.contacts, created];
          widget.onContactsChanged(newList);
        }
      } else {
        final updated = await widget.api.updateContact(result);
        if (updated != null) {
          final newList = widget.contacts.map((c) => c.id == updated.id ? updated : c).toList();
          widget.onContactsChanged(newList);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _delete(Contact c) async {
    setState(() => loading = true);
    try {
      if (c.id != null) await widget.api.deleteContact(c.id!);
      final newList = widget.contacts.where((x) => x.id != c.id).toList();
      widget.onContactsChanged(newList);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAuthed) {
      return const Center(child: Text('请登录后管理家属/联系人'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('家属与紧急联系人', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              FilledButton.icon(
                onPressed: loading ? null : () => _addOrEdit(),
                icon: const Icon(Icons.add),
                label: const Text('新增'),
              )
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '点击星标设置紧急联系人1，点击心标设置紧急联系人2',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else if (widget.contacts.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: Text('暂无联系人，点击新增添加')))
          else
            ...widget.contacts.map((c) => _buildContactCard(c)),
        ],
      ),
    );
  }

  Widget _buildContactCard(Contact c) {
    final isEmergency1 = c.id == widget.emergencyContactId1;
    final isEmergency2 = c.id == widget.emergencyContactId2;
    return Card(
      elevation: (isEmergency1 || isEmergency2) ? 2 : 0,
      color: isEmergency1 ? Colors.red.shade50 : (isEmergency2 ? Colors.orange.shade50 : null),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isEmergency1 ? Colors.red.shade200 : (isEmergency2 ? Colors.orange.shade200 : Colors.grey.shade200),
          width: (isEmergency1 || isEmergency2) ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                widget.onSetEmergency1(c);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已将 ${c.name} 设为紧急联系人1'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Icon(
                isEmergency1 ? Icons.star : Icons.star_border,
                color: isEmergency1 ? Colors.amber : Colors.grey,
                size: 28,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                widget.onSetEmergency2(c);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已将 ${c.name} 设为紧急联系人2'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Icon(
                isEmergency2 ? Icons.favorite : Icons.favorite_border,
                color: isEmergency2 ? Colors.redAccent : Colors.grey,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(c.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      if (isEmergency1) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '紧急联系人1',
                            style: TextStyle(fontSize: 10, color: Colors.red),
                          ),
                        ),
                      ],
                      if (isEmergency2) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '紧急联系人2',
                            style: TextStyle(fontSize: 10, color: Colors.orange),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${c.relation.isNotEmpty ? c.relation : '家属'} · ${c.phone}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _addOrEdit(contact: c),
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: '编辑',
            ),
            IconButton(
              onPressed: () => _confirmDelete(c),
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              tooltip: '删除',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Contact c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除联系人'),
        content: Text('确定删除 ${c.name} 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      _delete(c);
    }
  }
}

class _ContactDialog extends StatefulWidget {
  const _ContactDialog({this.contact});
  final Contact? contact;

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  late TextEditingController name;
  late TextEditingController phone;
  late TextEditingController relation;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.contact?.name ?? '');
    phone = TextEditingController(text: widget.contact?.phone ?? '');
    relation = TextEditingController(text: widget.contact?.relation ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.contact == null ? '新增联系人' : '编辑联系人'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: '姓名')),
            TextField(controller: phone, decoration: const InputDecoration(labelText: '电话')),
            TextField(controller: relation, decoration: const InputDecoration(labelText: '关系')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty || phone.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              Contact(
                id: widget.contact?.id,
                name: name.text.trim(),
                phone: phone.text.trim(),
                relation: relation.text.trim(),
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
