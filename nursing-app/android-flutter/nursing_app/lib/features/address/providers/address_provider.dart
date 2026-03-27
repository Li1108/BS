import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_mapper.dart';
import '../data/models/address_model.dart';
import '../data/repositories/address_repository.dart';

/// 地址列表状态
class AddressListState {
  final List<AddressModel> addresses;
  final bool isLoading;
  final String? error;

  const AddressListState({
    this.addresses = const [],
    this.isLoading = false,
    this.error,
  });

  AddressListState copyWith({
    List<AddressModel>? addresses,
    bool? isLoading,
    String? error,
  }) {
    return AddressListState(
      addresses: addresses ?? this.addresses,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// 获取默认地址
  AddressModel? get defaultAddress {
    try {
      return addresses.firstWhere((a) => a.isDefaultAddress);
    } catch (_) {
      return addresses.isNotEmpty ? addresses.first : null;
    }
  }
}

/// 地址列表 Notifier
class AddressListNotifier extends StateNotifier<AddressListState> {
  final AddressRepository _repository;

  AddressListNotifier(this._repository) : super(const AddressListState());

  /// 加载地址列表
  Future<void> loadAddresses() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final addresses = await _repository.getAddresses();

      // 按默认地址排序
      addresses.sort((a, b) {
        if (a.isDefaultAddress && !b.isDefaultAddress) return -1;
        if (!a.isDefaultAddress && b.isDefaultAddress) return 1;
        return 0;
      });

      state = state.copyWith(addresses: addresses, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: normalizeErrorMessage(e, fallback: '加载地址失败'),
      );
    }
  }

  /// 添加地址
  Future<bool> addAddress(AddressRequest request) async {
    try {
      final address = await _repository.addAddress(request);
      if (address != null) {
        // 如果新地址是默认地址，更新其他地址状态
        List<AddressModel> updatedList;
        if (address.isDefaultAddress) {
          updatedList = state.addresses
              .map((a) => a.copyWith(isDefault: 0))
              .toList();
        } else {
          updatedList = List.from(state.addresses);
        }
        updatedList.insert(0, address);

        state = state.copyWith(addresses: updatedList);
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(
        error: normalizeErrorMessage(e, fallback: '保存地址失败'),
      );
      return false;
    }
  }

  /// 更新地址
  Future<bool> updateAddress(int addressId, AddressRequest request) async {
    final success = await _repository.updateAddress(addressId, request);
    if (success) {
      await loadAddresses(); // 重新加载以获取最新数据
    }
    return success;
  }

  /// 删除地址
  Future<bool> deleteAddress(int addressId) async {
    final success = await _repository.deleteAddress(addressId);
    if (success) {
      final updatedList = state.addresses
          .where((a) => a.id != addressId)
          .toList();
      state = state.copyWith(addresses: updatedList);
    }
    return success;
  }

  /// 设为默认地址
  Future<bool> setDefault(int addressId) async {
    final success = await _repository.setDefault(addressId);
    if (success) {
      final updatedList = state.addresses.map((a) {
        if (a.id == addressId) {
          return a.copyWith(isDefault: 1);
        } else {
          return a.copyWith(isDefault: 0);
        }
      }).toList();

      // 重新排序
      updatedList.sort((a, b) {
        if (a.isDefaultAddress && !b.isDefaultAddress) return -1;
        if (!a.isDefaultAddress && b.isDefaultAddress) return 1;
        return 0;
      });

      state = state.copyWith(addresses: updatedList);
    }
    return success;
  }
}

/// 地址列表 Provider
final addressListProvider =
    StateNotifierProvider<AddressListNotifier, AddressListState>((ref) {
      final repository = ref.watch(addressRepositoryProvider);
      return AddressListNotifier(repository);
    });

/// 默认地址 Provider
final defaultAddressProvider = Provider<AddressModel?>((ref) {
  return ref.watch(addressListProvider).defaultAddress;
});
